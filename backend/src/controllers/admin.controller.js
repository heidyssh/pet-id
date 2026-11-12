import { asyncHandler } from '../utils/asyncHandler.js';
import * as servicio from '../services/admin.service.js';

export const resumen = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.metricas() }));
export const usuarios = asyncHandler(async (req, res) => {
  const pagina = Math.max(1, Number(req.query.pagina) || 1);
  const limite = Math.min(100, Math.max(1, Number(req.query.limite) || 20));
  return res.json({ success: true, data: await servicio.listarUsuarios({ pagina, limite }) });
});
export const estadoUsuario = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.cambiarEstadoUsuario(req.params.idUsuario, req.body.activo, req.usuario.id_usuario) }));
export const rolesUsuario = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.asignarRoles(req.params.idUsuario, req.body.roles) }));
