
import {
  verificarPropiedadMascota,
  verificarPropiedadReporte,
  verificarAutorAvistamiento,
} from '../services/propiedad.service.js';

import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';

// ==========================================
// PROTECCIÓN DE MASCOTAS
// ==========================================

export const esDuenoMascota = asyncHandler(
  async (req, res, next) => {
    if (!req.usuario?.id_usuario) {
      throw new AppError('Autenticación requerida', 401);
    }

    const mascota = await verificarPropiedadMascota(
      req.params.idMascota,
      req.usuario.id_usuario
    );

    req.mascotaAutorizada = mascota;

    next();
  }
);

// ==========================================
// PROTECCIÓN DE REPORTES DE EXTRAVÍO
// ==========================================

export const esDuenoReporte = asyncHandler(
  async (req, res, next) => {
    if (!req.usuario?.id_usuario) {
      throw new AppError('Autenticación requerida', 401);
    }

    const reporte = await verificarPropiedadReporte(
      req.params.idReporte,
      req.usuario.id_usuario
    );

    req.reporteAutorizado = reporte;

    next();
  }
);

// ==========================================
// PROTECCIÓN DE AVISTAMIENTOS
// ==========================================

export const esAutorAvistamiento = asyncHandler(
  async (req, res, next) => {
    if (!req.usuario?.id_usuario) {
      throw new AppError('Autenticación requerida', 401);
    }

    const avistamiento = await verificarAutorAvistamiento(
      req.params.idAvistamiento,
      req.usuario.id_usuario
    );

    req.avistamientoAutorizado = avistamiento;

    next();
  }
);
