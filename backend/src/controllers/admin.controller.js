import { asyncHandler } from '../utils/asyncHandler.js';
import { AppError } from '../utils/AppError.js';
import * as servicio from '../services/admin.service.js';

function filtros(query, permitidos = {}) {
  const pagina = Math.max(1, Math.trunc(Number(query.pagina)) || 1);
  const limite = Math.min(100, Math.max(1, Math.trunc(Number(query.limite)) || 20));
  const resultado = { pagina, limite };

  for (const [campo, valores] of Object.entries(permitidos)) {
    if (query[campo] !== undefined) {
      if (!valores.includes(query[campo])) {
        throw new AppError(`Filtro ${campo} invalido`, 400);
      }
      resultado[campo] = query[campo];
    }
  }

  return resultado;
}

function booleanoOpcional(valor) {
  if (valor === undefined) return undefined;
  if (valor === 'true') return true;
  if (valor === 'false') return false;
  throw new AppError('Filtro verificada invalido', 400);
}

export const resumen = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.metricas() }));
export const usuarios = asyncHandler(async (req, res) => {
  const pagina = Math.max(1, Number(req.query.pagina) || 1);
  const limite = Math.min(100, Math.max(1, Number(req.query.limite) || 20));
  return res.json({ success: true, data: await servicio.listarUsuarios({ pagina, limite }) });
});
export const estadoUsuario = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.cambiarEstadoUsuario(req.params.idUsuario, req.body.activo, req.usuario.id_usuario) }));
export const rolesUsuario = asyncHandler(async (req, res) => res.json({ success: true, data: await servicio.asignarRoles(req.params.idUsuario, req.body.roles) }));

export const organizaciones = asyncHandler(async (req, res) => res.json({
  success: true,
  data: await servicio.listarOrganizacionesAdmin({
    ...filtros(req.query, { tipo: ['veterinaria', 'refugio'] }),
    verificada: booleanoOpcional(req.query.verificada),
  }),
}));

export const extravios = asyncHandler(async (req, res) => res.json({
  success: true,
  data: await servicio.listarExtraviosAdmin(
    filtros(req.query, { estado: ['activo', 'resuelto', 'cancelado'] })
  ),
}));

export const avistamientos = asyncHandler(async (req, res) => res.json({
  success: true,
  data: await servicio.listarAvistamientosAdmin(
    filtros(req.query, { estado: ['registrado', 'revisado', 'descartado'] })
  ),
}));

export const estadoAvistamiento = asyncHandler(async (req, res) => res.json({
  success: true,
  data: await servicio.cambiarEstadoAvistamiento(
    req.params.idAvistamiento,
    req.body.estado
  ),
}));
