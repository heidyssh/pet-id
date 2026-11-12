import { asyncHandler } from '../utils/asyncHandler.js';
import {
  crearOrganizacion,
  listarOrganizaciones,
  actualizarOrganizacion,
  guardarMembresia,
  listarMiembros,
  verificarOrganizacion,
} from '../services/organizacion.service.js';

export const registrar = asyncHandler(async (req, res) => res.status(201).json({
  success: true,
  message: 'Organización registrada; queda pendiente de verificación',
  data: await crearOrganizacion(req.body, req.usuario.id_usuario),
}));

export const listar = asyncHandler(async (req, res) => res.json({
  success: true,
  data: { items: await listarOrganizaciones({ tipo: req.query.tipo }) },
}));

export const actualizar = asyncHandler(async (req, res) => res.json({
  success: true,
  message: 'Organización actualizada correctamente',
  data: await actualizarOrganizacion(req.organizacion, req.body),
}));

export const guardarMiembro = asyncHandler(async (req, res) => res.json({
  success: true,
  message: 'Membresía actualizada correctamente',
  data: await guardarMembresia(req.params.idOrganizacion, req.body),
}));

export const miembros = asyncHandler(async (req, res) => res.json({
  success: true,
  data: { items: await listarMiembros(req.params.idOrganizacion) },
}));

export const cambiarVerificacion = asyncHandler(async (req, res) => res.json({
  success: true,
  data: await verificarOrganizacion(req.params.idOrganizacion, req.body.verificada),
}));
