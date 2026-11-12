import { sequelize } from '../config/sequelize.js';
import {
  Organizacion,
  UsuarioOrganizacion,
  Usuario,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';

export async function crearOrganizacion(datos, idUsuario) {
  return sequelize.transaction(async (transaction) => {
    const organizacion = await Organizacion.create({
      nombre: datos.nombre,
      tipo: datos.tipo,
      direccion: datos.direccion ?? null,
      telefono: datos.telefono ?? null,
      verificada: false,
    }, { transaction });
    await UsuarioOrganizacion.create({
      id_usuario: idUsuario,
      id_organizacion: organizacion.id_organizacion,
      cargo: datos.cargo,
      activo: true,
    }, { transaction });
    return organizacion;
  });
}

export async function listarOrganizaciones({ tipo } = {}) {
  const where = { verificada: true };
  if (tipo) where.tipo = tipo;
  return Organizacion.findAll({
    where,
    attributes: ['id_organizacion', 'nombre', 'tipo', 'direccion', 'telefono'],
    order: [['nombre', 'ASC']],
  });
}

export async function actualizarOrganizacion(organizacion, datos) {
  await organizacion.update(datos);
  return organizacion;
}

export async function guardarMembresia(idOrganizacion, datos) {
  const usuario = await Usuario.findByPk(datos.id_usuario);
  if (!usuario || !usuario.activo) throw new AppError('Usuario no disponible', 404);
  const [membresia] = await UsuarioOrganizacion.upsert({
    id_usuario: datos.id_usuario,
    id_organizacion: idOrganizacion,
    cargo: datos.cargo ?? null,
    activo: datos.activo,
  });
  return membresia;
}

export async function listarMiembros(idOrganizacion) {
  const organizacion = await Organizacion.findByPk(idOrganizacion);
  return organizacion.getMiembros({
    attributes: ['id_usuario', 'nombre', 'apellido', 'correo'],
    joinTableAttributes: ['cargo', 'activo'],
  });
}

export async function verificarOrganizacion(idOrganizacion, verificada) {
  if (!validarIdPositivo(idOrganizacion)) throw new AppError('Identificador inválido', 400);
  const organizacion = await Organizacion.findByPk(idOrganizacion);
  if (!organizacion) throw new AppError('Organización no encontrada', 404);
  await organizacion.update({ verificada });
  return organizacion;
}
