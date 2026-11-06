
import {
  renovarSesion,
  listarSesiones,
  cerrarSesion,
  cerrarTodasSesiones,
} from '../services/sesion.service.js';

import { asyncHandler } from '../utils/asyncHandler.js';

// =====================================
// RENOVAR TOKENS
// =====================================

export const renovar = asyncHandler(async (req, res) => {
  const resultado = await renovarSesion(
    req.body.refresh_token
  );

  res.setHeader('Cache-Control', 'no-store');

  return res.status(200).json({
    success: true,
    data: resultado,
  });
});

// =====================================
// LISTAR SESIONES
// =====================================

export const misSesiones = asyncHandler(
  async (req, res) => {
    const sesiones = await listarSesiones(
      req.usuario.id_usuario
    );

    res.setHeader('Cache-Control', 'no-store');

    return res.status(200).json({
      success: true,
      data: sesiones.map((sesion) => ({
        ...sesion.toJSON(),
        es_actual:
          sesion.id_sesion === req.sesion.id_sesion,
      })),
    });
  }
);

// =====================================
// CERRAR SESIÓN ACTUAL
// =====================================

export const cerrarActual = asyncHandler(
  async (req, res) => {
    await cerrarSesion(
      req.usuario.id_usuario,
      req.sesion.id_sesion
    );

    res.setHeader('Cache-Control', 'no-store');

    return res.status(200).json({
      success: true,
      message: 'Sesión cerrada correctamente',
    });
  }
);

// =====================================
// CERRAR SESIÓN DE OTRO DISPOSITIVO
// =====================================

export const cerrarDispositivo = asyncHandler(
  async (req, res) => {
    await cerrarSesion(
      req.usuario.id_usuario,
      req.params.idSesion
    );

    return res.status(200).json({
      success: true,
      message: 'Sesión revocada correctamente',
    });
  }
);

// =====================================
// CERRAR TODAS LAS SESIONES
// =====================================

export const cerrarTodas = asyncHandler(
  async (req, res) => {
    await cerrarTodasSesiones(
      req.usuario.id_usuario
    );

    res.setHeader('Cache-Control', 'no-store');

    return res.status(200).json({
      success: true,
      message: 'Todas las sesiones fueron cerradas',
    });
  }
);
