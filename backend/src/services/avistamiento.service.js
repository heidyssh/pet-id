
import {
  Avistamiento,
  Especie,
  FotoAvistamiento,
} from '../models/index.js';

import { AppError } from '../utils/AppError.js';

import {
  crearPuntoGeografico,
  validarIdPositivo,
} from '../utils/ubicacion.js';
import { generarCoincidencias } from './coincidencia.service.js';

const atributosPublicos = [
  'id_avistamiento',
  'id_especie',
  'fecha_avistamiento',
  'fecha_registro',
  'referencia_lugar',
  'color_principal',
  'tamano',
  'senas_particulares',
  'descripcion',
  'estado',
];

const relacionesPublicas = [{
  model: Especie,
  as: 'especie',
  attributes: ['id_especie', 'nombre'],
  required: false,
}, {
  model: FotoAvistamiento,
  as: 'fotos',
  attributes: [
    'id_foto', 'url_original', 'url_recorte',
    'tipo_captura', 'estado_procesamiento',
  ],
  required: false,
}];

function verificarId(id) {
  if (!validarIdPositivo(id)) {
    throw new AppError(
      'Identificador inválido',
      400
    );
  }

  return id;
}

// ==========================================
// REGISTRAR AVISTAMIENTO
// ==========================================

export async function crearAvistamiento(
  datos,
  idUsuario = null,
  generarCandidatos = true
) {
  if (datos.id_especie != null) {
    const especie = await Especie.findByPk(
      datos.id_especie
    );

    if (!especie) {
      throw new AppError(
        'Especie no válida',
        400
      );
    }
  }

  const avistamiento = await Avistamiento.create({
    id_usuario: idUsuario,
    id_especie: datos.id_especie ?? null,
    fecha_avistamiento: new Date(
      datos.fecha_avistamiento
    ),
    ubicacion: crearPuntoGeografico(
      datos.ubicacion
    ),
    referencia_lugar: datos.referencia_lugar ?? null,
    color_principal: datos.color_principal ?? null,
    tamano: datos.tamano ?? null,
    senas_particulares:
      datos.senas_particulares ?? null,
    descripcion: datos.descripcion,
    estado: 'registrado',
  });

  if (generarCandidatos) {
    await generarCoincidencias(avistamiento.id_avistamiento);
  }

  // No incluir coordenadas exactas
  // ni el identificador del usuario en la respuesta.
  return {
    id_avistamiento: avistamiento.id_avistamiento,
    fecha_avistamiento: avistamiento.fecha_avistamiento,
    fecha_registro: avistamiento.fecha_registro,
    estado: avistamiento.estado,
  };
}

export async function asignarEspecieDetectada(idAvistamiento, etiqueta) {
  const etiquetaNormalizada = String(etiqueta).toLowerCase();
  const nombre = etiquetaNormalizada === 'dog'
    ? 'Perro'
    : etiquetaNormalizada === 'cat' ? 'Gato' : null;
  if (!nombre) return null;

  const avistamiento = await Avistamiento.findByPk(idAvistamiento);
  if (!avistamiento || avistamiento.id_especie) {
    return avistamiento?.id_especie ?? null;
  }

  const especie = await Especie.findOne({ where: { nombre } });
  if (!especie) return null;
  await avistamiento.update({ id_especie: especie.id_especie });
  return especie.id_especie;
}

// ==========================================
// LISTADO PÚBLICO
// ==========================================

export async function listarAvistamientos({
  pagina,
  limite,
  id_especie,
}) {
  const where = {
    estado: ['registrado', 'revisado'],
  };

  if (id_especie !== undefined) {
    where.id_especie = id_especie;
  }

  const { count, rows } =
    await Avistamiento.findAndCountAll({
      where,
      attributes: atributosPublicos,
      include: relacionesPublicas,
      order: [['fecha_avistamiento', 'DESC']],
      limit: limite,
      offset: (pagina - 1) * limite,
      distinct: true,
    });

  return {
    avistamientos: rows,
    paginacion: {
      pagina,
      limite,
      total: count,
      total_paginas: Math.ceil(count / limite),
    },
  };
}

// ==========================================
// MIS AVISTAMIENTOS
// ==========================================

export async function listarMisAvistamientos(
  idUsuario,
  { pagina, limite }
) {
  const { count, rows } =
    await Avistamiento.findAndCountAll({
      where: {
        id_usuario: idUsuario,
      },
      attributes: [
        ...atributosPublicos,
        'ubicacion',
      ],
      include: relacionesPublicas,
      order: [['fecha_registro', 'DESC']],
      limit: limite,
      offset: (pagina - 1) * limite,
      distinct: true,
    });

  return {
    avistamientos: rows,
    paginacion: {
      pagina,
      limite,
      total: count,
      total_paginas: Math.ceil(count / limite),
    },
  };
}

// ==========================================
// DETALLE PÚBLICO
// ==========================================

export async function obtenerAvistamiento(idAvistamiento) {
  const avistamiento = await Avistamiento.findOne({
    where: {
      id_avistamiento: verificarId(idAvistamiento),
      estado: ['registrado', 'revisado'],
    },
    attributes: atributosPublicos,
    include: relacionesPublicas,
  });

  if (!avistamiento) {
    throw new AppError(
      'Avistamiento no encontrado',
      404
    );
  }

  return avistamiento;
}
