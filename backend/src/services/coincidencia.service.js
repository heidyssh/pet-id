import { QueryTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';
import {
  Coincidencia,
  ReporteExtravio,
  Mascota,
  Avistamiento,
  Especie,
  FotoAvistamiento,
  VectorVisual,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';
import { crearNotificacion } from './notificacion.service.js';
import { prepararConsultaVisual } from './foto.service.js';
import { similitudCoseno, DIMENSIONES_VECTOR } from './embedding.service.js';
import { env } from '../config/config.js';

export async function buscarMascotasSimilares(archivo, limite = 5, idUsuarioExcluir = null) {
  const { deteccion, vector } = await prepararConsultaVisual(archivo);
  const candidatos = await sequelize.query(`
    SELECT
      vv.vector,
      m.id_mascota,
      m.nombre,
      m.color_principal,
      m.tamano,
      m.senas_particulares,
      fm.url_original,
      fm.url_recorte,
      fm.es_principal,
      r.id_reporte,
      r.fecha_perdida,
      r.referencia_lugar
    FROM vectores_visuales vv
    JOIN fotos_mascotas fm ON fm.id_foto = vv.id_foto_mascota
    JOIN mascotas m ON m.id_mascota = fm.id_mascota
    JOIN reportes_extravio r ON r.id_mascota = m.id_mascota
    WHERE vv.modelo = :modelo
      AND vv.dimensiones = :dimensiones
      AND r.estado = 'activo'
      AND (:id_usuario_excluir IS NULL OR m.id_dueno <> :id_usuario_excluir)
  `, {
    replacements: {
      modelo: env.DINO_MODEL_ID,
      dimensiones: DIMENSIONES_VECTOR,
      id_usuario_excluir: idUsuarioExcluir,
    },
    type: QueryTypes.SELECT,
  });

  const porMascota = new Map();
  for (const candidato of candidatos) {
    const similitud = similitudCoseno(vector, candidato.vector);
    if (similitud === null || !Number.isFinite(similitud)) continue;
    const anterior = porMascota.get(String(candidato.id_mascota));
    if (!anterior || similitud > anterior.similitud) {
      porMascota.set(String(candidato.id_mascota), { ...candidato, similitud });
    }
  }

  const coincidencias = [...porMascota.values()]
    .sort((a, b) => b.similitud - a.similitud)
    .slice(0, limite)
    .map((item) => ({
      id_mascota: item.id_mascota,
      nombre: item.nombre,
      color_principal: item.color_principal,
      tamano: item.tamano,
      senas_particulares: item.senas_particulares,
      foto: item.url_recorte ?? item.url_original,
      id_reporte: item.id_reporte,
      fecha_perdida: item.fecha_perdida,
      referencia_lugar: item.referencia_lugar,
      similitud: Number(Math.max(0, Math.min(1, item.similitud)).toFixed(6)),
      porcentaje_similitud: Number(
        (Math.max(0, Math.min(1, item.similitud)) * 100).toFixed(2)
      ),
    }));

  return {
    deteccion: {
      etiqueta: deteccion.etiqueta,
      confianza: deteccion.confianza,
    },
    modelo: env.DINO_MODEL_ID,
    total_candidatos: porMascota.size,
    coincidencias,
    aviso: 'La similitud visual orienta la búsqueda; no confirma la identidad de la mascota.',
  };
}

export async function registrarCoincidenciaSugerida(
  idAvistamiento,
  idReporte,
  idUsuario
) {
  if (!validarIdPositivo(idAvistamiento) || !validarIdPositivo(idReporte)) {
    throw new AppError('Identificador inválido', 400);
  }

  const reporte = await ReporteExtravio.findOne({
    where: { id_reporte: idReporte, estado: 'activo' },
    include: [{
      model: Mascota,
      as: 'mascota',
      required: true,
      attributes: ['id_dueno', 'nombre'],
    }],
  });
  if (!reporte) {
    throw new AppError('La alerta seleccionada ya no está activa', 409);
  }
  if (idUsuario != null && String(reporte.mascota.id_dueno) === String(idUsuario)) {
    throw new AppError(
      'No puedes registrar un avistamiento sobre tu propia mascota',
      403
    );
  }

  const [coincidencia, creada] = await Coincidencia.findOrCreate({
    where: {
      id_avistamiento: idAvistamiento,
      id_reporte: idReporte,
    },
    defaults: {
      metodo: 'descripcion',
      puntuacion: null,
      puntuacion_visual: null,
      puntuacion_contexto: null,
      estado_revision: 'pendiente',
      detalles: {
        sugerida_por_reportante: true,
        identidad_sin_confirmar: true,
      },
    },
  });

  if (creada) {
    await crearNotificacion({
      id_usuario: reporte.mascota.id_dueno,
      tipo: 'coincidencia_nueva',
      titulo: 'Posible avistamiento de tu mascota',
      mensaje: `Una persona cree haber visto a ${reporte.mascota.nombre}. Revisa la foto y los detalles antes de confirmarlo.`,
      datos: {
        id_coincidencia: coincidencia.id_coincidencia,
        id_reporte: idReporte,
        id_avistamiento: idAvistamiento,
      },
    });
  }

  return coincidencia;
}

async function puntuacionesContexto(idAvistamiento) {
  const filas = await sequelize.query(`
    SELECT
      r.id_reporte,
      LEAST(1, (
        CASE
          WHEN a.id_especie IS NULL THEN 0.15
          WHEN a.id_especie = m.id_especie THEN 0.30
          ELSE 0
        END +
        CASE
          WHEN a.ubicacion IS NULL OR r.ubicacion IS NULL THEN 0.10
          ELSE GREATEST(0, 0.30 * (1 - LEAST(
            ST_Distance(a.ubicacion, r.ubicacion) / 1000,
            GREATEST(r.radio_km, 25)
          ) / GREATEST(r.radio_km, 25)))
        END +
        CASE
          WHEN a.fecha_avistamiento >= r.fecha_perdida
           AND a.fecha_avistamiento <= r.fecha_perdida + INTERVAL '90 days'
          THEN 0.15 ELSE 0
        END +
        CASE
          WHEN NULLIF(LOWER(BTRIM(a.color_principal)), '') =
               NULLIF(LOWER(BTRIM(m.color_principal)), '')
          THEN 0.10 ELSE 0
        END +
        CASE WHEN a.tamano IS NOT NULL AND a.tamano = m.tamano
          THEN 0.05 ELSE 0 END +
        CASE
          WHEN m.senas_particulares IS NOT NULL
           AND LENGTH(BTRIM(m.senas_particulares)) >= 4
           AND POSITION(
             LOWER(BTRIM(m.senas_particulares)) IN
             LOWER(COALESCE(a.senas_particulares, '') || ' ' || COALESCE(a.descripcion, ''))
           ) > 0
          THEN 0.10 ELSE 0
        END
      ))::float AS puntuacion_contexto
    FROM avistamientos a
    CROSS JOIN reportes_extravio r
    JOIN mascotas m ON m.id_mascota = r.id_mascota
    WHERE a.id_avistamiento = :id_avistamiento
      AND a.estado IN ('registrado', 'revisado')
      AND r.estado = 'activo'
      AND a.fecha_avistamiento >= r.fecha_perdida - INTERVAL '1 day'
      AND (a.id_usuario IS NULL OR a.id_usuario <> m.id_dueno)
  `, {
    replacements: { id_avistamiento: idAvistamiento },
    type: QueryTypes.SELECT,
  });
  return new Map(filas.map((fila) => [String(fila.id_reporte), Number(fila.puntuacion_contexto)]));
}

async function candidatosVisuales(vector, idAvistamiento) {
  const filas = await sequelize.query(`
    SELECT
      vv.vector,
      r.id_reporte,
      m.id_mascota,
      m.id_dueno,
      m.nombre,
      fm.url_original,
      fm.url_recorte
    FROM avistamientos a
    CROSS JOIN reportes_extravio r
    JOIN mascotas m ON m.id_mascota = r.id_mascota
    JOIN fotos_mascotas fm ON fm.id_mascota = m.id_mascota
    JOIN vectores_visuales vv ON vv.id_foto_mascota = fm.id_foto
    WHERE a.id_avistamiento = :id_avistamiento
      AND r.estado = 'activo'
      AND vv.modelo = :modelo
      AND vv.dimensiones = :dimensiones
      AND a.fecha_avistamiento >= r.fecha_perdida - INTERVAL '1 day'
      AND (a.id_usuario IS NULL OR a.id_usuario <> m.id_dueno)
  `, {
    replacements: {
      id_avistamiento: idAvistamiento,
      modelo: env.DINO_MODEL_ID,
      dimensiones: DIMENSIONES_VECTOR,
    },
    type: QueryTypes.SELECT,
  });

  const mejores = new Map();
  for (const fila of filas) {
    const similitud = similitudCoseno(vector, fila.vector);
    if (similitud === null || !Number.isFinite(similitud)) continue;
    const puntuacionVisual = Math.max(0, Math.min(1, similitud));
    const clave = String(fila.id_reporte);
    const anterior = mejores.get(clave);
    if (!anterior || puntuacionVisual > anterior.puntuacion_visual) {
      mejores.set(clave, { ...fila, puntuacion_visual: puntuacionVisual });
    }
  }
  return [...mejores.values()].sort(
    (a, b) => b.puntuacion_visual - a.puntuacion_visual
  );
}

export async function generarCoincidenciasVisuales(idAvistamiento, idFotoAvistamiento) {
  if (!validarIdPositivo(idAvistamiento) || !validarIdPositivo(idFotoAvistamiento)) {
    throw new AppError('Identificador inválido', 400);
  }

  const embedding = await VectorVisual.findOne({
    where: { id_foto_avistamiento: idFotoAvistamiento },
  });
  if (!embedding) {
    return { total: 0, coincidencias: [], procesamiento: 'sin_vector_visual' };
  }

  const contexto = await puntuacionesContexto(idAvistamiento);
  const candidatos = (await candidatosVisuales(embedding.vector, idAvistamiento))
    .slice(0, env.VISUAL_MATCH_LIMIT);
  const resultados = [];

  for (const candidato of candidatos) {
    const puntuacionContexto = contexto.get(String(candidato.id_reporte)) ?? 0;
    const metodo = puntuacionContexto > 0 ? 'mixto' : 'visual';
    const puntuacion = metodo === 'mixto'
      ? 0.70 * candidato.puntuacion_visual + 0.30 * puntuacionContexto
      : candidato.puntuacion_visual;
    const superaUmbral = candidato.puntuacion_visual >= env.VISUAL_MATCH_MIN_SCORE;
    let coincidencia = null;
    let creada = false;

    if (superaUmbral) {
      [coincidencia, creada] = await Coincidencia.findOrCreate({
        where: {
          id_avistamiento: idAvistamiento,
          id_reporte: candidato.id_reporte,
        },
        defaults: {
          metodo,
          puntuacion: puntuacion.toFixed(4),
          puntuacion_visual: candidato.puntuacion_visual.toFixed(4),
          puntuacion_contexto: puntuacionContexto.toFixed(4),
          estado_revision: 'pendiente',
          detalles: {
            modelo: env.DINO_MODEL_ID,
            pesos: metodo === 'mixto' ? { visual: 0.70, contexto: 0.30 } : { visual: 1 },
          },
        },
      });

      if (!creada && coincidencia.estado_revision === 'pendiente') {
        const puntuacionAnterior = Number(coincidencia.puntuacion ?? 0);
        await coincidencia.update({
          metodo: coincidencia.metodo === 'descripcion' ? 'mixto' : metodo,
          puntuacion: Math.max(puntuacionAnterior, puntuacion).toFixed(4),
          puntuacion_visual: Math.max(
            Number(coincidencia.puntuacion_visual ?? 0),
            candidato.puntuacion_visual
          ).toFixed(4),
          puntuacion_contexto: Math.max(
            Number(coincidencia.puntuacion_contexto ?? 0),
            puntuacionContexto
          ).toFixed(4),
          detalles: {
            modelo: env.DINO_MODEL_ID,
            pesos: { visual: 0.70, contexto: 0.30 },
          },
        });
      }

      if (creada) {
        await crearNotificacion({
          id_usuario: candidato.id_dueno,
          tipo: 'coincidencia_nueva',
          titulo: 'Nueva posible coincidencia visual',
          mensaje: `Un escaneo encontró una posible coincidencia con ${candidato.nombre}.`,
          datos: {
            id_coincidencia: coincidencia.id_coincidencia,
            id_reporte: candidato.id_reporte,
            id_avistamiento: idAvistamiento,
          },
        });
      }
    }

    resultados.push({
      id_coincidencia: coincidencia?.id_coincidencia ?? null,
      id_reporte: candidato.id_reporte,
      id_mascota: candidato.id_mascota,
      nombre: candidato.nombre,
      foto: candidato.url_recorte ?? candidato.url_original,
      metodo,
      puntuacion: Number(puntuacion.toFixed(4)),
      puntuacion_visual: Number(candidato.puntuacion_visual.toFixed(4)),
      puntuacion_contexto: Number(puntuacionContexto.toFixed(4)),
      requiere_revision: true,
      persistida: superaUmbral,
    });
  }

  return {
    total: resultados.length,
    coincidencias: resultados,
    procesamiento: 'visual_completado',
    aviso: 'Las puntuaciones ordenan candidatos y no confirman identidad.',
  };
}

export async function generarCoincidencias(idAvistamiento) {
  const [creadas] = await sequelize.query(`
    WITH candidatos AS (
      SELECT
        a.id_avistamiento,
        r.id_reporte,
        LEAST(1, (
          CASE
            WHEN a.id_especie IS NULL THEN 0.15
            WHEN a.id_especie = m.id_especie THEN 0.30
            ELSE 0
          END +
          CASE
            WHEN a.ubicacion IS NULL OR r.ubicacion IS NULL THEN 0.10
            ELSE GREATEST(0, 0.30 * (1 - LEAST(
              ST_Distance(a.ubicacion, r.ubicacion) / 1000,
              GREATEST(r.radio_km, 25)
            ) / GREATEST(r.radio_km, 25)))
          END +
          CASE
            WHEN a.fecha_avistamiento >= r.fecha_perdida
             AND a.fecha_avistamiento <= r.fecha_perdida + INTERVAL '90 days'
            THEN 0.15 ELSE 0
          END +
          CASE
            WHEN NULLIF(LOWER(BTRIM(a.color_principal)), '') =
                 NULLIF(LOWER(BTRIM(m.color_principal)), '')
            THEN 0.10 ELSE 0
          END +
          CASE WHEN a.tamano IS NOT NULL AND a.tamano = m.tamano
            THEN 0.05 ELSE 0 END +
          CASE
            WHEN m.senas_particulares IS NOT NULL
             AND LENGTH(BTRIM(m.senas_particulares)) >= 4
             AND POSITION(
               LOWER(BTRIM(m.senas_particulares)) IN
               LOWER(COALESCE(a.senas_particulares, '') || ' ' || COALESCE(a.descripcion, ''))
             ) > 0
            THEN 0.10 ELSE 0
          END
        ))::numeric(5,4) AS puntuacion
      FROM avistamientos a
      CROSS JOIN reportes_extravio r
      JOIN mascotas m ON m.id_mascota = r.id_mascota
      WHERE a.id_avistamiento = :id_avistamiento
        AND a.estado IN ('registrado', 'revisado')
        AND r.estado = 'activo'
        AND (a.id_especie IS NULL OR a.id_especie = m.id_especie)
        AND a.fecha_avistamiento >= r.fecha_perdida - INTERVAL '1 day'
        AND (a.id_usuario IS NULL OR a.id_usuario <> m.id_dueno)
        AND (
          a.ubicacion IS NULL OR r.ubicacion IS NULL OR
          ST_DWithin(a.ubicacion, r.ubicacion, 25000)
        )
    )
    INSERT INTO coincidencias (
      id_avistamiento,
      id_reporte,
      metodo,
      puntuacion,
      puntuacion_contexto,
      detalles,
      estado_revision,
      fecha_deteccion
    )
    SELECT id_avistamiento, id_reporte, 'descripcion', puntuacion,
           puntuacion, '{"regla":"descripcion_geografia"}'::jsonb,
           'pendiente', NOW()
    FROM candidatos
    WHERE puntuacion >= 0.45
    ON CONFLICT (id_avistamiento, id_reporte) DO NOTHING
    RETURNING id_coincidencia, id_reporte
  `, {
    replacements: { id_avistamiento: idAvistamiento },
  });

  for (const creada of creadas) {
    const reporte = await ReporteExtravio.findByPk(creada.id_reporte, {
      include: [{
        model: Mascota,
        as: 'mascota',
        attributes: ['id_dueno', 'nombre'],
      }],
    });
    if (reporte?.mascota) {
      await crearNotificacion({
        id_usuario: reporte.mascota.id_dueno,
        tipo: 'coincidencia_nueva',
        titulo: 'Nueva posible coincidencia',
        mensaje: `Hay un avistamiento compatible con ${reporte.mascota.nombre}.`,
        datos: {
          id_coincidencia: creada.id_coincidencia,
          id_reporte: creada.id_reporte,
        },
      });
    }
  }

  return creadas.length;
}

export async function listarCoincidenciasReporte(idReporte, idUsuario) {
  if (!validarIdPositivo(idReporte)) {
    throw new AppError('Identificador inválido', 400);
  }

  const reporte = await ReporteExtravio.findOne({
    where: { id_reporte: idReporte },
    include: [{
      model: Mascota,
      as: 'mascota',
      required: true,
      where: { id_dueno: idUsuario },
      attributes: ['id_mascota', 'nombre'],
    }],
  });
  if (!reporte) throw new AppError('Reporte no encontrado', 404);

  const coincidencias = await Coincidencia.findAll({
    where: { id_reporte: idReporte },
    attributes: [
      'id_coincidencia', 'metodo', 'puntuacion',
      'puntuacion_visual', 'puntuacion_contexto', 'detalles',
      'estado_revision', 'fecha_deteccion',
    ],
    include: [{
      model: Avistamiento,
      as: 'avistamiento',
      attributes: [
        'id_avistamiento', 'id_especie', 'fecha_avistamiento',
        'referencia_lugar', 'color_principal', 'tamano',
        'senas_particulares', 'descripcion', 'ubicacion',
      ],
      include: [
        { model: Especie, as: 'especie', attributes: ['nombre'], required: false },
        { model: FotoAvistamiento, as: 'fotos', attributes: ['url_original', 'url_recorte'], required: false },
      ],
    }],
    order: [['puntuacion', 'DESC'], ['fecha_deteccion', 'DESC']],
  });

  // Este endpoint ya verificó que el reporte pertenece al dueño. Solo aquí se
  // entrega el punto exacto; los listados públicos conservan coordenadas
  // redondeadas para proteger a quien realizó el avistamiento.
  return coincidencias.map((coincidencia) => {
    const item = coincidencia.toJSON();
    const coordenadas = item.avistamiento?.ubicacion?.coordinates;
    if (Array.isArray(coordenadas) && coordenadas.length === 2) {
      item.avistamiento.ubicacion = {
        latitud: coordenadas[1],
        longitud: coordenadas[0],
      };
    }
    return item;
  });
}

export async function revisarCoincidencia(idCoincidencia, idUsuario, estado) {
  if (!validarIdPositivo(idCoincidencia)) {
    throw new AppError('Identificador inválido', 400);
  }

  const coincidencia = await Coincidencia.findOne({
    where: { id_coincidencia: idCoincidencia },
    include: [{
      model: ReporteExtravio,
      as: 'reporte',
      required: true,
      include: [{
        model: Mascota,
        as: 'mascota',
        required: true,
        where: { id_dueno: idUsuario },
        attributes: [],
      }],
    }],
  });
  if (!coincidencia) throw new AppError('Coincidencia no encontrada', 404);

  await coincidencia.update({ estado_revision: estado });
  return coincidencia;
}
