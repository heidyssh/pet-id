
import {
  Mascota,
  ReporteExtravio,
  Avistamiento,
} from '../models/index.js';

import { AppError } from '../utils/AppError.js';

// ==========================================
// VALIDAR IDENTIFICADORES
// ==========================================

function validarId(id) {
  if (
    typeof id !== 'string' ||
    !/^[1-9]\d*$/.test(id) ||
    id.length > 19 ||
    BigInt(id) > 9223372036854775807n
  ) {
    throw new AppError('Identificador inválido', 400);
  }

  return id;
}

// ==========================================
// VERIFICAR PROPIEDAD DE UNA MASCOTA
// ==========================================

export async function verificarPropiedadMascota(
  idMascota,
  idUsuario
) {
  const mascota = await Mascota.findOne({
    where: {
      id_mascota: validarId(idMascota),
      id_dueno: idUsuario,
    },
  });

  if (!mascota) {
    throw new AppError('Mascota no encontrada', 404);
  }

  return mascota;
}

// ==========================================
// VERIFICAR PROPIEDAD DE UN REPORTE
// ==========================================

export async function verificarPropiedadReporte(
  idReporte,
  idUsuario
) {
  const reporte = await ReporteExtravio.findOne({
    where: {
      id_reporte: validarId(idReporte),
    },
    include: [{
      model: Mascota,
      as: 'mascota',
      required: true,
      where: {
        id_dueno: idUsuario,
      },
    }],
  });

  if (!reporte) {
    throw new AppError('Reporte no encontrado', 404);
  }

  return reporte;
}

// ==========================================
// VERIFICAR AUTOR DE UN AVISTAMIENTO
// ==========================================

export async function verificarAutorAvistamiento(
  idAvistamiento,
  idUsuario
) {
  const avistamiento = await Avistamiento.findOne({
    where: {
      id_avistamiento: validarId(idAvistamiento),
      id_usuario: idUsuario,
    },
  });

  if (!avistamiento) {
    throw new AppError('Avistamiento no encontrado', 404);
  }

  return avistamiento;
}
