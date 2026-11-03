
import {
  registrarUsuario,
  iniciarSesion,
  obtenerPerfil,
} from '../services/auth.service.js';

import { asyncHandler } from '../utils/asyncHandler.js';

export const registro = asyncHandler(async (req, res) => {
  const resultado = await registrarUsuario(req.body);

  res.setHeader('Cache-Control', 'no-store');

  return res.status(201).json({
    success: true,
    message: 'Usuario registrado correctamente',
    data: resultado,
  });
});

export const login = asyncHandler(async (req, res) => {
  const resultado = await iniciarSesion(req.body);

  res.setHeader('Cache-Control', 'no-store');

  return res.status(200).json({
    success: true,
    message: 'Inicio de sesión correcto',
    data: resultado,
  });
});

export const me = asyncHandler(async (req, res) => {
  const usuario = await obtenerPerfil(
    req.usuario.id_usuario
  );

  res.setHeader('Cache-Control', 'no-store');

  return res.status(200).json({
    success: true,
    data: usuario,
  });
});
