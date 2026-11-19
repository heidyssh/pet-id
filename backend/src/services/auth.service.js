
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

import { sequelize } from '../config/sequelize.js';
import { Usuario, Rol, UsuarioRol } from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { crearSesionConTokens } from './sesion.service.js';
import { insertarOrganizacion } from './organizacion.service.js';
import { guardarUbicacionAlertas } from './alertaUbicacion.service.js';

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
    activo: usuario.activo,
  };
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
      throw new AppError(
        'No se pudo registrar una cuenta con esos datos',
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
    usuario: datosPublicos(usuario),
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
