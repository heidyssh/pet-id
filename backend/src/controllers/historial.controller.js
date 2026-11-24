import { asyncHandler } from '../utils/asyncHandler.js';
import {
  crearRegistroClinico, crearRegistroClinicoPropio,
  historialDeMascota, actualizarRegistroClinico,
} from '../services/historial.service.js';

export const crear = asyncHandler(async (req, res) => res.status(201).json({
  success: true,
  message: 'Registro clínico creado correctamente',
  data: await crearRegistroClinico(req.body, req.params.idMascota, req.organizacion, req.usuario.id_usuario),
}));

export const listarPropio = asyncHandler(async (req, res) => res.json({
  success: true,
  data: await historialDeMascota(req.params.idMascota, req.usuario.id_usuario),
}));

export const crearPropio = asyncHandler(async (req, res) => res.status(201).json({
  success: true,
  message: 'Registro de salud creado correctamente',
  data: await crearRegistroClinicoPropio(
    req.body,
    req.params.idMascota,
    req.usuario.id_usuario
  ),
}));

export const actualizar = asyncHandler(async (req, res) => res.json({
  success: true,
  message: 'Registro clínico actualizado correctamente',
  data: await actualizarRegistroClinico(req.params.idHistorial, req.params.idOrganizacion, req.body),
}));
