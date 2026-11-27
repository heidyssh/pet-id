
import {
  registrarUsuario,
  iniciarSesion,
  obtenerPerfil,
  actualizarPerfil,
  actualizarFotoPerfil,
  eliminarFotoPerfil,
} from '../services/auth.service.js';
import {
  solicitarVerificacion,
  verificarCorreo,
  solicitarRecuperacion,
  restablecerContrasena,
} from '../services/seguridadCuenta.service.js';

import { asyncHandler } from '../utils/asyncHandler.js';
import { iniciarSesionGoogle } from '../services/googleAuth.service.js';

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
  const resultado = await iniciarSesion(
  req.body,
  req.get('user-agent') ?? ''
);

  res.setHeader('Cache-Control', 'no-store');

  return res.status(200).json({
    success: true,
    message: 'Inicio de sesión correcto',
    data: resultado,
  });
});

export const loginGoogle = asyncHandler(async (req, res) => {
  const data = await iniciarSesionGoogle(req.body.id_token, req.get('user-agent') ?? '');
  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).json({ success: true, data });
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

export const actualizarMe = asyncHandler(async (req, res) => {
  const usuario = await actualizarPerfil(req.usuario.id_usuario, req.body);
  res.setHeader('Cache-Control', 'no-store');
  return res.json({
    success: true,
    message: 'Perfil actualizado correctamente',
    data: usuario,
  });
});

export const actualizarMiFoto = asyncHandler(async (req, res) => {
  const usuario = await actualizarFotoPerfil(req.usuario.id_usuario, req.file);
  res.setHeader('Cache-Control', 'no-store');
  return res.json({
    success: true,
    message: 'Foto de perfil actualizada',
    data: usuario,
  });
});

export const eliminarMiFoto = asyncHandler(async (req, res) => {
  const usuario = await eliminarFotoPerfil(req.usuario.id_usuario);
  res.setHeader('Cache-Control', 'no-store');
  return res.json({
    success: true,
    message: 'Foto de perfil eliminada',
    data: usuario,
  });
});

export const reenviarVerificacion = asyncHandler(
  async (req, res) => {
    const message = await solicitarVerificacion(
      req.body.correo
    );

    return res.status(200).json({
      success: true,
      message,
    });
  }
);

export const confirmarCorreo = asyncHandler(
  async (req, res) => {
    await verificarCorreo(req.body.token);

    return res.status(200).json({
      success: true,
      message: 'Correo verificado correctamente',
    });
  }
);

export const solicitarCambioPassword = asyncHandler(
  async (req, res) => {
    const message = await solicitarRecuperacion(
      req.body.correo
    );

    return res.status(200).json({
      success: true,
      message,
    });
  }
);

export const confirmarCambioPassword = asyncHandler(
  async (req, res) => {
    await restablecerContrasena(
      req.body.token,
      req.body.password
    );

    return res.status(200).json({
      success: true,
      message: 'Contraseña actualizada correctamente',
    });
  }
);
