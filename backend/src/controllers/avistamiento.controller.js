
import {
  crearAvistamiento,
  listarAvistamientos,
  listarMisAvistamientos,
  obtenerAvistamiento,
} from '../services/avistamiento.service.js';

import {
  listarAvistamientosSchema,
} from '../schemas/avistamiento.schema.js';

import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';

function obtenerFiltros(query) {
  const resultado = listarAvistamientosSchema.safeParse(
    query
  );

  if (!resultado.success) {
    throw new AppError(
      'Parámetros de búsqueda inválidos',
      400
    );
  }

  return resultado.data;
}

// Avistamiento anónimo
export const registrarAnonimo = asyncHandler(
  async (req, res) => {
    const avistamiento = await crearAvistamiento(
      req.body,
      null
    );

    return res.status(201).json({
      success: true,
      message: 'Avistamiento registrado correctamente',
      data: avistamiento,
    });
  }
);

// Avistamiento de usuario autenticado
export const registrarAutenticado = asyncHandler(
  async (req, res) => {
    const avistamiento = await crearAvistamiento(
      req.body,
      req.usuario.id_usuario
    );

    return res.status(201).json({
      success: true,
      message: 'Avistamiento registrado correctamente',
      data: avistamiento,
    });
  }
);

// Listar avistamientos públicos
export const obtenerAvistamientos = asyncHandler(
  async (req, res) => {
    const resultado = await listarAvistamientos(
      obtenerFiltros(req.query)
    );

    return res.status(200).json({
      success: true,
      data: resultado,
    });
  }
);

// Listar avistamientos del usuario
export const obtenerMisAvistamientos = asyncHandler(
  async (req, res) => {
    const resultado = await listarMisAvistamientos(
      req.usuario.id_usuario,
      obtenerFiltros(req.query)
    );

    return res.status(200).json({
      success: true,
      data: resultado,
    });
  }
);

// Detalle público
export const detalleAvistamiento = asyncHandler(
  async (req, res) => {
    const avistamiento = await obtenerAvistamiento(
      req.params.idAvistamiento
    );

    return res.status(200).json({
      success: true,
      data: avistamiento,
    });
  }
);
