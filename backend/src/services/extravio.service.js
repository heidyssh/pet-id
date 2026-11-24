
import { sequelize } from '../config/sequelize.js';

import {
  Mascota,
  ReporteExtravio,
  FotoMascota,
} from '../models/index.js';

import { AppError } from '../utils/AppError.js';

import {
  crearPuntoGeografico,
  validarIdPositivo,
} from '../utils/ubicacion.js';
import { notificarSuscriptoresCercanos } from './alertaUbicacion.service.js';

const atributosPublicos = [
  'id_reporte',
  'fecha_perdida',
  'fecha_reporte',
  'referencia_lugar',
  'estado',
];

const atributosMascotaPublicos = [
  'id_mascota',
  'nombre',
  'id_especie',
  'id_raza',
  'sexo',
  'color_principal',
  'tamano',
  'senas_particulares',
];

const fotosMascotaPublicas = {
  model: FotoMascota,
  as: 'fotos',
  attributes: ['id_foto', 'url_original', 'url_recorte', 'es_principal'],
  required: false,
};

function verificarId(id) {
  if (!validarIdPositivo(id)) {
    throw new AppError('Identificador inválido', 400);
  }

  return id;
}

// =========================================
// CREAR REPORTE DE EXTRAVÍO
// =========================================

export async function crearReporteExtravio(
  datos,
  idUsuario
) {
  const ahora = new Date();
  const fechaSolicitada = new Date(datos.fecha_perdida);
  const fechaPerdida = fechaSolicitada > ahora
    ? ahora
    : fechaSolicitada;

  const reporteCreado = await sequelize.transaction(async (transaction) => {
    const mascota = await Mascota.findOne({
      where: {
        id_mascota: datos.id_mascota,
        id_dueno: idUsuario,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!mascota) {
      throw new AppError(
        'Mascota no encontrada',
        404
      );
    }

    if (mascota.estado === 'en_adopcion') {
      throw new AppError(
        'La mascota está actualmente en adopción',
        409
      );
    }

    const reporteActivo = await ReporteExtravio.findOne({
      where: {
        id_mascota: mascota.id_mascota,
        estado: 'activo',
      },
      transaction,
    });

    if (reporteActivo) {
      throw new AppError(
        'Esta mascota ya tiene un extravío activo',
        409
      );
    }

    const reporte = await ReporteExtravio.create({
      id_mascota: mascota.id_mascota,
      fecha_perdida: fechaPerdida,
      ubicacion: crearPuntoGeografico(
        datos.ubicacion
      ),
      referencia_lugar: datos.referencia_lugar ?? null,
      radio_km: datos.radio_km,
      estado: 'activo',
    }, { transaction });

    await mascota.update({
      estado: 'perdido',
    }, { transaction });

    return reporte;
  });

  await notificarSuscriptoresCercanos(reporteCreado.id_reporte);
  return reporteCreado;
}

// =========================================
// CONSULTAR EXTRAVÍOS ACTIVOS
// =========================================

export async function listarExtraviosPublicos({
  pagina,
  limite,
}) {
  const { count, rows } =
    await ReporteExtravio.findAndCountAll({
      where: { estado: 'activo' },
      attributes: atributosPublicos,
      include: [{
        model: Mascota,
        as: 'mascota',
        attributes: atributosMascotaPublicos,
        include: [fotosMascotaPublicas],
      }],
      order: [['fecha_reporte', 'DESC']],
      limit: limite,
      offset: (pagina - 1) * limite,
      distinct: true,
    });

  return {
    reportes: rows,
    paginacion: {
      pagina,
      limite,
      total: count,
      total_paginas: Math.ceil(count / limite),
    },
  };
}

// =========================================
// CONSULTAR MIS REPORTES
// =========================================

export async function listarMisExtravios(
  idUsuario,
  { pagina, limite }
) {
  const { count, rows } =
    await ReporteExtravio.findAndCountAll({
      attributes: [
        ...atributosPublicos,
        'id_mascota',
        'ubicacion',
        'radio_km',
        'fecha_resolucion',
      ],
      include: [{
        model: Mascota,
        as: 'mascota',
        required: true,
        where: { id_dueno: idUsuario },
        attributes: atributosMascotaPublicos,
        include: [fotosMascotaPublicas],
      }],
      order: [['fecha_reporte', 'DESC']],
      limit: limite,
      offset: (pagina - 1) * limite,
      distinct: true,
    });

  return {
    reportes: rows,
    paginacion: {
      pagina,
      limite,
      total: count,
      total_paginas: Math.ceil(count / limite),
    },
  };
}

// =========================================
// DETALLE PÚBLICO
// =========================================

export async function obtenerExtravioPublico(idReporte) {
  const reporte = await ReporteExtravio.findOne({
    where: {
      id_reporte: verificarId(idReporte),
      estado: 'activo',
    },
    attributes: atributosPublicos,
    include: [{
      model: Mascota,
      as: 'mascota',
      attributes: atributosMascotaPublicos,
      include: [fotosMascotaPublicas],
    }],
  });

  if (!reporte) {
    throw new AppError('Reporte no encontrado', 404);
  }

  return reporte;
}

// =========================================
// RESOLVER EXTRAVÍO
// =========================================

export async function resolverExtravio(
  idReporte,
  idUsuario
) {
  verificarId(idReporte);

  return sequelize.transaction(async (transaction) => {
    const reporte = await ReporteExtravio.findOne({
      where: {
        id_reporte: idReporte,
      },
      transaction,
    });

    if (!reporte) {
      throw new AppError(
        'Reporte no encontrado',
        404
      );
    }

    const mascota = await Mascota.findOne({
      where: {
        id_mascota: reporte.id_mascota,
        id_dueno: idUsuario,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!mascota) {
      throw new AppError(
        'Reporte no encontrado',
        404
      );
    }

    await reporte.reload({
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (reporte.estado !== 'activo') {
      throw new AppError(
        'El reporte ya no está activo',
        409
      );
    }

    await reporte.update({
      estado: 'resuelto',
      fecha_resolucion: new Date(),
    }, { transaction });

    await mascota.update({
      estado: 'a_salvo',
    }, { transaction });

    return {
      id_reporte: reporte.id_reporte,
      estado: reporte.estado,
      fecha_resolucion: reporte.fecha_resolucion,
    };
  });
}
