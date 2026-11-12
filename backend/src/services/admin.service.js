import { sequelize } from '../config/sequelize.js';
import {
  Usuario, Rol, UsuarioRol, Mascota, ReporteExtravio,
  Avistamiento, Organizacion, PublicacionAdopcion,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';

export async function metricas() {
  const [usuarios, mascotas, extraviosActivos, avistamientos, organizacionesPendientes, adopcionesActivas] = await Promise.all([
    Usuario.count(), Mascota.count(), ReporteExtravio.count({ where: { estado: 'activo' } }),
    Avistamiento.count(), Organizacion.count({ where: { verificada: false } }),
    PublicacionAdopcion.count({ where: { estado: 'disponible' } }),
  ]);
  return { usuarios, mascotas, extravios_activos: extraviosActivos, avistamientos, organizaciones_pendientes: organizacionesPendientes, adopciones_activas: adopcionesActivas };
}

export async function listarUsuarios({ pagina, limite }) {
  const { count, rows } = await Usuario.findAndCountAll({
    attributes: ['id_usuario', 'nombre', 'apellido', 'correo', 'telefono', 'activo', 'correo_verificado', 'fecha_registro'],
    include: [{ model: Rol, as: 'roles', attributes: ['nombre'], through: { attributes: [] } }],
    order: [['fecha_registro', 'DESC']], limit: limite, offset: (pagina - 1) * limite, distinct: true,
  });
  return { items: rows, paginacion: { pagina, limite, total: count, total_paginas: Math.ceil(count / limite) } };
}

export async function cambiarEstadoUsuario(idUsuario, activo, idAdministrador) {
  if (!validarIdPositivo(idUsuario)) throw new AppError('Usuario inválido', 400);
  if (!activo && String(idUsuario) === String(idAdministrador)) throw new AppError('No puede desactivar su propia cuenta', 409);
  const usuario = await Usuario.findByPk(idUsuario);
  if (!usuario) throw new AppError('Usuario no encontrado', 404);
  await usuario.update({ activo });
  if (!activo) await usuario.increment('token_version');
  return { id_usuario: usuario.id_usuario, activo: usuario.activo };
}

export async function asignarRoles(idUsuario, nombres) {
  if (!validarIdPositivo(idUsuario)) throw new AppError('Usuario inválido', 400);
  return sequelize.transaction(async (transaction) => {
    const usuario = await Usuario.findByPk(idUsuario, { transaction });
    if (!usuario) throw new AppError('Usuario no encontrado', 404);
    const roles = await Rol.findAll({ where: { nombre: nombres }, transaction });
    if (roles.length !== new Set(nombres).size) throw new AppError('Uno o más roles no existen', 400);
    await UsuarioRol.destroy({ where: { id_usuario: idUsuario }, transaction });
    await UsuarioRol.bulkCreate(roles.map((rol) => ({ id_usuario: idUsuario, id_rol: rol.id_rol })), { transaction });
    await usuario.increment('token_version', { transaction });
    return { id_usuario: idUsuario, roles: nombres };
  });
}
