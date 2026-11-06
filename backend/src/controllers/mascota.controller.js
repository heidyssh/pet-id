
import {
  crearMascota,
  listarMisMascotas,
  obtenerMiMascota,
  actualizarMiMascota,
} from '../services/mascota.service.js';

import { paginacionMascotasSchema } from
  '../schemas/mascota.schema.js';

import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';

// ==========================================
// REGISTRAR
// ==========================================

export const registrarMascota = asyncHandler(
  async (req, res) => {
    const mascota = await crearMascota(
      req.body,
      req.usuario.id_usuario
    );

    return res.status(201).json({
      success: true,
      message: 'Mascota registrada correctamente',
      data: mascota,
    });
  }
);

// ==========================================
// LISTAR MIS MASCOTAS
// ==========================================

export const misMascotas = asyncHandler(
  async (req, res) => {
    const resultado = paginacionMascotasSchema.safeParse(
      req.query
    );

    if (!resultado.success) {
      throw new AppError(
        'Parámetros de paginación inválidos',
        400
      );
    }

    const mascotas = await listarMisMascotas(
      req.usuario.id_usuario,
      resultado.data
    );

    return res.status(200).json({
      success: true,
      data: mascotas,
    });
  }
);

// ==========================================
// CONSULTAR UNA MASCOTA
// ==========================================

export const detalleMascota = asyncHandler(
  async (req, res) => {
    const mascota = await obtenerMiMascota(
      req.params.idMascota,
      req.usuario.id_usuario
    );

    return res.status(200).json({
      success: true,
      data: mascota,
    });
  }
);

// ==========================================
// ACTUALIZAR
// ==========================================

export const editarMascota = asyncHandler(
  async (req, res) => {
    const mascota = await actualizarMiMascota(
      req.params.idMascota,
      req.usuario.id_usuario,
      req.body
    );

    return res.status(200).json({
      success: true,
      message: 'Mascota actualizada correctamente',
      data: mascota,
    });
  }
);
