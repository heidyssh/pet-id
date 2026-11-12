import { asyncHandler } from '../utils/asyncHandler.js';
import { listarNotificaciones, marcarLeida } from '../services/notificacion.service.js';

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
