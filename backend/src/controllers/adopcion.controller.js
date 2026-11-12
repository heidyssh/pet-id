import { asyncHandler } from '../utils/asyncHandler.js';
import * as servicio from '../services/adopcion.service.js';

export const crearPublicacion = asyncHandler(async (req, res) => res.status(201).json({ success: true, data: await servicio.crearPublicacion(req.body, req.usuario.id_usuario) }));
export const listarPublicaciones = asyncHandler(async (req, res) => res.json({ success: true, data: { items: await servicio.listarPublicaciones() } }));
export const detalle = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.detallePublicacion(req.params.idPublicacion) }));
export const solicitar = asyncHandler(async (req, res) => res.status(201).json({ success: true, data: await servicio.solicitarAdopcion(req.params.idPublicacion, req.usuario.id_usuario, req.body.mensaje) }));
export const mias = asyncHandler(async (req, res) => res.json({ success: true, data: { items: await servicio.misSolicitudes(req.usuario.id_usuario) } }));
export const solicitudes = asyncHandler(async (req, res) => res.json({ success: true, data: { items: await servicio.solicitudesPublicacion(req.params.idPublicacion, req.usuario.id_usuario) } }));
export const revisar = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.revisarSolicitud(req.params.idSolicitud, req.usuario.id_usuario, req.body.estado) }));
export const cancelar = asyncHandler(async (req, res) => { await servicio.cancelarSolicitud(req.params.idSolicitud, req.usuario.id_usuario); return res.json({ success: true, message: 'Solicitud cancelada correctamente' }); });
export const cerrar = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.cerrarPublicacion(req.params.idPublicacion, req.usuario.id_usuario, req.body.estado) }));
