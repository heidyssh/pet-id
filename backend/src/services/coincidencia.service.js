import { QueryTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';
import {
  Coincidencia,
  ReporteExtravio,
  Mascota,
  Avistamiento,
  Especie,
  FotoAvistamiento,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';
import { crearNotificacion } from './notificacion.service.js';

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
      estado_revision,
      fecha_deteccion
    )
    SELECT id_avistamiento, id_reporte, 'descripcion', puntuacion,
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

  return Coincidencia.findAll({
    where: { id_reporte: idReporte },
    attributes: [
      'id_coincidencia', 'metodo', 'puntuacion',
      'estado_revision', 'fecha_deteccion',
    ],
    include: [{
      model: Avistamiento,
      as: 'avistamiento',
      attributes: [
        'id_avistamiento', 'id_especie', 'fecha_avistamiento',
        'referencia_lugar', 'color_principal', 'tamano',
        'senas_particulares', 'descripcion',
      ],
      include: [
        { model: Especie, as: 'especie', attributes: ['nombre'], required: false },
        { model: FotoAvistamiento, as: 'fotos', attributes: ['url_original', 'url_recorte'], required: false },
      ],
    }],
    order: [['puntuacion', 'DESC'], ['fecha_deteccion', 'DESC']],
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
