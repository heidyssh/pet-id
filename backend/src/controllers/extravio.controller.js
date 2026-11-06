
import {
  crearReporteExtravio,
  listarExtraviosPublicos,
  listarMisExtravios,
  obtenerExtravioPublico,
  resolverExtravio,
} from '../services/extravio.service.js';

import {
  listarExtraviosSchema,
} from '../schemas/extravio.schema.js';

import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';

function obtenerPaginacion(query) {
  const resultado = listarExtraviosSchema.safeParse(query);

  if (!resultado.success) {
    throw new AppError(
      'Parámetros de paginación inválidos',
      400
    );
  }

  return resultado.data;
}

export const registrarExtravio = asyncHandler(
  async (req, res) => {
    const reporte = await crearReporteExtravio(
      req.body,
      req.usuario.id_usuario
    );

    return res.status(201).json({
      success: true,
      message: 'Extravío registrado correctamente',
      data: reporte,
    });
  }
);

export const obtenerExtravios = asyncHandler(
  async (req, res) => {
    const resultado = await listarExtraviosPublicos(
      obtenerPaginacion(req.query)
    );

    return res.status(200).json({
      success: true,
      data: resultado,
    });
  }
);

export const obtenerMisExtravios = asyncHandler(
  async (req, res) => {
    const resultado = await listarMisExtravios(
      req.usuario.id_usuario,
      obtenerPaginacion(req.query)
    );

    return res.status(200).json({
      success: true,
      data: resultado,
    });
  }
);

export const detalleExtravio = asyncHandler(
  async (req, res) => {
    const reporte = await obtenerExtravioPublico(
      req.params.idReporte
    );

    return res.status(200).json({
      success: true,
      data: reporte,
    });
  }
);

export const marcarExtravioResuelto = asyncHandler(
  async (req, res) => {
    const resultado = await resolverExtravio(
      req.params.idReporte,
      req.usuario.id_usuario
    );

    return res.status(200).json({
      success: true,
      message: 'Extravío marcado como resuelto',
      data: resultado,
    });
  }
);
