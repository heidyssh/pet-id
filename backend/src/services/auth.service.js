
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import sharp from 'sharp';
import { Op } from 'sequelize';

import { sequelize } from '../config/sequelize.js';
import { Usuario, Rol, UsuarioRol } from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { crearSesionConTokens } from './sesion.service.js';
import { insertarOrganizacion } from './organizacion.service.js';
import { guardarUbicacionAlertas } from './alertaUbicacion.service.js';
import { eliminarImagen, guardarImagen } from './almacenamientoImagen.service.js';

const HASH_ROUNDS = 12;

const HASH_FICTICIO = bcrypt.hashSync(
  'PetID-Password-Ficticio',
  HASH_ROUNDS
);

function crearToken(usuario) {
  const secret = process.env.JWT_SECRET;

  if (!secret || Buffer.byteLength(secret, 'utf8') < 32) {
    throw new AppError(
      'Configuración de autenticación incompleta',
      500
    );
  }

  return jwt.sign({
    ver: usuario.token_version,
  }, secret, {
    algorithm: 'HS256',
    subject: String(usuario.id_usuario),
    issuer: 'petid-api',
    audience: 'petid-client',
    expiresIn: '15m',
  });
}

export function datosPublicos(usuario) {
  return {
    id_usuario: usuario.id_usuario,
    nombre: usuario.nombre,
    apellido: usuario.apellido,
    correo: usuario.correo,
    telefono: usuario.telefono,
    foto_perfil_url: usuario.foto_perfil_url,
    activo: usuario.activo,
  };
}

export async function actualizarFotoPerfil(idUsuario, archivo) {
  if (!archivo) throw new AppError('Selecciona una imagen', 400);
  const usuario = await Usuario.unscoped().findByPk(idUsuario);
  if (!usuario || !usuario.activo) {
    throw new AppError('Usuario no autorizado', 401);
  }

  let buffer;
  try {
    buffer = await sharp(archivo.buffer, { failOn: 'error' })
      .rotate()
      .resize(800, 800, { fit: 'cover', position: 'attention' })
      .webp({ quality: 86 })
      .toBuffer();
  } catch {
    throw new AppError('La imagen no es válida o está dañada', 400);
  }

  const anterior = usuario.foto_perfil_id
    ? { proveedor: usuario.foto_perfil_proveedor, id: usuario.foto_perfil_id }
    : null;
  const nueva = await guardarImagen(buffer, 'perfil');
  try {
    await usuario.update({
      foto_perfil_url: nueva.url,
      foto_perfil_proveedor: nueva.proveedor,
      foto_perfil_id: nueva.id,
    });
  } catch (error) {
    await eliminarImagen(nueva).catch(() => {});
    throw error;
  }
  if (anterior) await eliminarImagen(anterior).catch(() => {});
  return obtenerPerfil(idUsuario);
}

export async function eliminarFotoPerfil(idUsuario) {
  const usuario = await Usuario.unscoped().findByPk(idUsuario);
  if (!usuario || !usuario.activo) {
    throw new AppError('Usuario no autorizado', 401);
  }
  const anterior = usuario.foto_perfil_id
    ? { proveedor: usuario.foto_perfil_proveedor, id: usuario.foto_perfil_id }
    : null;
  await usuario.update({
    foto_perfil_url: null,
    foto_perfil_proveedor: null,
    foto_perfil_id: null,
  });
  if (anterior) await eliminarImagen(anterior).catch(() => {});
  return obtenerPerfil(idUsuario);
}

// ==========================================
// REGISTRAR CIUDADANO
// ==========================================

export async function crearCiudadano(datos, transaction) {
  const rol = await Rol.findOne({ where: { nombre: 'ciudadano' }, transaction });
  if (!rol) throw new AppError('Configuración de roles incompleta', 500);
  const usuario = await Usuario.create(datos, { transaction });
  await UsuarioRol.create({
    id_usuario: usuario.id_usuario,
    id_rol: rol.id_rol,
  }, { transaction });
  return usuario;
}

export async function registrarUsuario(datos) {
  const existente = await Usuario.unscoped().findOne({
    where: {
      [Op.or]: [
        { correo: datos.correo },
        { telefono: datos.telefono },
      ],
    },
    attributes: ['correo', 'telefono'],
  });
  if (existente?.correo === datos.correo) {
    throw new AppError('Este correo ya está registrado', 409);
  }
  if (existente?.telefono === datos.telefono) {
    throw new AppError('Este teléfono ya está registrado', 409);
  }

  const password_hash = await bcrypt.hash(
    datos.password,
    HASH_ROUNDS
  );

  let usuario;

  try {
    usuario = await sequelize.transaction(async (transaction) => {
      const nuevoUsuario = await crearCiudadano({
        nombre: datos.nombre,
        apellido: datos.apellido,
        correo: datos.correo,
        telefono: datos.telefono ?? null,
        dni: datos.dni ?? null,
        password_hash,
        activo: true,
        correo_verificado: true,
      }, transaction);

      if (datos.organizacion) {
        await insertarOrganizacion(datos.organizacion, nuevoUsuario.id_usuario, transaction);
      }
      if (datos.alertas_ubicacion) {
        await guardarUbicacionAlertas(nuevoUsuario.id_usuario, datos.alertas_ubicacion, transaction);
      }
      return nuevoUsuario;
    });
  } catch (error) {
    if (error.name === 'SequelizeUniqueConstraintError') {
      const campo = error.errors?.[0]?.path;
      throw new AppError(
        campo === 'telefono'
          ? 'Este teléfono ya está registrado'
          : campo === 'correo'
          ? 'Este correo ya está registrado'
          : 'No se pudo registrar una cuenta con esos datos',
        409
      );
    }

    throw error;
  }

  return {
    usuario: datosPublicos(usuario),
    message: 'Cuenta creada correctamente',
  };
}

// ==========================================
// INICIAR SESIÓN
// ==========================================

export async function iniciarSesion(datos, agenteUsuario = '') {
  const usuario = await Usuario.scope('withPassword').findOne({
    where: { correo: datos.correo },
  });

  const passwordValido = await bcrypt.compare(
    datos.password,
    usuario?.password_hash ?? HASH_FICTICIO
  );

  if (!usuario || !passwordValido || !usuario.activo) {
    throw new AppError(
      'Correo o contraseña incorrectos',
      401
    );
  }

  const tokens = await crearSesionConTokens(
    usuario,
    agenteUsuario
  );

  return {
    usuario: await obtenerPerfil(usuario.id_usuario),
    ...tokens,
  };
}

// ==========================================
// OBTENER PERFIL
// ==========================================

export async function obtenerPerfil(idUsuario) {
  const usuario = await Usuario.findByPk(idUsuario, {
    include: [{
      model: Rol,
      as: 'roles',
      attributes: ['id_rol', 'nombre'],
      through: { attributes: [] },
    }],
  });

  if (!usuario || !usuario.activo) {
    throw new AppError('Usuario no autorizado', 401);
  }

  return {
    ...datosPublicos(usuario),
    roles: usuario.roles.map((rol) => rol.nombre),
  };
}

export async function actualizarPerfil(idUsuario, datos) {
  const usuario = await Usuario.findByPk(idUsuario);
  if (!usuario || !usuario.activo) {
    throw new AppError('Usuario no autorizado', 401);
  }
  if (datos.telefono && datos.telefono !== usuario.telefono) {
    const existente = await Usuario.unscoped().findOne({
      where: { telefono: datos.telefono, id_usuario: { [Op.ne]: idUsuario } },
      attributes: ['id_usuario'],
    });
    if (existente) throw new AppError('Este teléfono ya está registrado', 409);
  }
  try {
    await usuario.update(datos);
  } catch (error) {
    if (error.name === 'SequelizeUniqueConstraintError') {
      throw new AppError('Este teléfono ya está registrado', 409);
    }
    throw error;
  }
  return obtenerPerfil(usuario.id_usuario);
}
