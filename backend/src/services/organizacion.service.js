import { sequelize } from '../config/sequelize.js';
import {
  Organizacion,
  UsuarioOrganizacion,
  Usuario,
  Rol,
  UsuarioRol,
} from '../models/index.js';
import { ROLES } from '../constants/roles.js';
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
  return sequelize.transaction(async (transaction) => {
    const [usuario, organizacion] = await Promise.all([
      Usuario.findByPk(datos.id_usuario, { transaction }),
      Organizacion.findByPk(idOrganizacion, { transaction }),
    ]);
    if (!usuario || !usuario.activo) throw new AppError('Usuario no disponible', 404);
    if (!organizacion) throw new AppError('Organizacion no encontrada', 404);

    const [membresia] = await UsuarioOrganizacion.upsert({
      id_usuario: datos.id_usuario,
      id_organizacion: idOrganizacion,
      cargo: datos.cargo ?? null,
      activo: datos.activo,
    }, { transaction });

    if (datos.activo && organizacion.verificada) {
      const nombreRol = organizacion.tipo === 'veterinaria'
        ? ROLES.PERSONAL_VETERINARIO
        : ROLES.PERSONAL_REFUGIO;
      const rol = await Rol.findOne({ where: { nombre: nombreRol }, transaction });
      if (rol) {
        await UsuarioRol.findOrCreate({
          where: { id_usuario: datos.id_usuario, id_rol: rol.id_rol },
          defaults: { id_usuario: datos.id_usuario, id_rol: rol.id_rol },
          transaction,
        });
      }
    }

    return membresia;
  });
}

export async function listarMiembros(idOrganizacion) {
  const organizacion = await Organizacion.findByPk(idOrganizacion);
  return organizacion.getMiembros({
    attributes: ['id_usuario', 'nombre', 'apellido', 'correo'],
    joinTableAttributes: ['cargo', 'activo'],
  });
}

export async function verificarOrganizacion(idOrganizacion, verificada) {
  if (!validarIdPositivo(idOrganizacion)) {
    throw new AppError('Identificador invalido', 400);
  }

  return sequelize.transaction(async (transaction) => {
    const organizacion = await Organizacion.findByPk(idOrganizacion, {
      transaction,
      lock: transaction.LOCK.UPDATE,
    });
    if (!organizacion) throw new AppError('Organizacion no encontrada', 404);

    await organizacion.update({ verificada }, { transaction });

    if (verificada) {
      const nombreRol = organizacion.tipo === 'veterinaria'
        ? ROLES.PERSONAL_VETERINARIO
        : ROLES.PERSONAL_REFUGIO;
      const rol = await Rol.findOne({ where: { nombre: nombreRol }, transaction });
      const membresias = await UsuarioOrganizacion.findAll({
        where: { id_organizacion: idOrganizacion, activo: true },
        attributes: ['id_usuario'],
        transaction,
      });

      if (rol && membresias.length) {
        await UsuarioRol.bulkCreate(
          membresias.map(({ id_usuario }) => ({
            id_usuario,
            id_rol: rol.id_rol,
          })),
          { transaction, ignoreDuplicates: true }
        );
      }
    }

    return organizacion;
  });
}
