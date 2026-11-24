import { asyncHandler } from '../utils/asyncHandler.js';
import { listarNotificaciones, marcarLeida } from '../services/notificacion.service.js';
import {
  actualizarUbicacionAlertas,
  desactivarUbicacionAlertas,
  obtenerUbicacionAlertas,
} from '../services/alertaUbicacion.service.js';
import {
  registrarDispositivoPush,
  eliminarDispositivoPush,
} from '../services/push.service.js';

export const listar = asyncHandler(async (req, res) => {
  const pagina = Math.max(1, Number(req.query.pagina) || 1);
  const limite = Math.min(50, Math.max(1, Number(req.query.limite) || 20));
  const data = await listarNotificaciones(req.usuario.id_usuario, {
    pagina, limite, soloNoLeidas: req.query.solo_no_leidas === 'true',
  });
  return res.json({ success: true, data });
});

export const leer = asyncHandler(async (req, res) => {
  await marcarLeida(req.params.idNotificacion, req.usuario.id_usuario);
  return res.json({ success: true, message: 'Notificación marcada como leída' });
});

export const actualizarUbicacion = asyncHandler(async (req, res) => {
  const data = await actualizarUbicacionAlertas(req.usuario.id_usuario, req.body);
  return res.json({
    success: true,
    message: 'Ubicación de alertas actualizada',
    data,
  });
});

export const desactivarUbicacion = asyncHandler(async (req, res) => {
  await desactivarUbicacionAlertas(req.usuario.id_usuario);
  return res.json({ success: true, message: 'Alertas por ubicación desactivadas' });
});

export const consultarUbicacion = asyncHandler(async (req, res) => {
  const data = await obtenerUbicacionAlertas(req.usuario.id_usuario);
  return res.json({ success: true, data });
});

export const registrarDispositivo = asyncHandler(async (req, res) => {
  const data = await registrarDispositivoPush(req.usuario.id_usuario, req.body);
  return res.status(201).json({
    success: true,
    message: 'Dispositivo registrado para notificaciones push',
    data,
  });
});

export const eliminarDispositivo = asyncHandler(async (req, res) => {
  await eliminarDispositivoPush(req.usuario.id_usuario, req.body.token);
  return res.json({ success: true, message: 'Dispositivo push eliminado' });
});
