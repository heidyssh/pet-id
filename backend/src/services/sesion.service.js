
import {
  randomBytes,
  randomUUID,
  createHash,
  timingSafeEqual,
} from 'node:crypto';

import jwt from 'jsonwebtoken';
import { Op } from 'sequelize';

import { sequelize } from '../config/sequelize.js';

import {
  Usuario,
  SesionUsuario,
  RefreshTokenUsado,
} from '../models/index.js';

import { AppError } from '../utils/AppError.js';

const ACCESS_DURATION = '15m';
const SESSION_DURATION_MS = 7 * 24 * 60 * 60 * 1000;
const IDLE_DURATION_MS = 24 * 60 * 60 * 1000;

function hashToken(token) {
  return createHash('sha256')
    .update(token)
    .digest('hex');
}

function hashIgual(a, b) {
  const bufferA = Buffer.from(a, 'hex');
  const bufferB = Buffer.from(b, 'hex');

  return bufferA.length === bufferB.length &&
    timingSafeEqual(bufferA, bufferB);
}

function crearRefreshToken(idSesion) {
  const secreto = randomBytes(32).toString('hex');
  return `${idSesion}.${secreto}`;
}

function extraerSesion(token) {
  if (typeof token !== 'string') {
    throw new AppError('Sesión inválida', 401);
  }

  const partes = token.split('.');

  if (
    partes.length !== 2 ||
    !/^[0-9a-f-]{36}$/i.test(partes[0]) ||
    !/^[a-f0-9]{64}$/.test(partes[1])
  ) {
    throw new AppError('Sesión inválida', 401);
  }

  return partes[0];
}

function crearAccessToken(usuario, idSesion) {
  if (!process.env.JWT_SECRET ||
      Buffer.byteLength(process.env.JWT_SECRET, 'utf8') < 32) {
    throw new AppError('Configuración JWT inválida', 500);
  }

  return jwt.sign(
    {
      ver: usuario.token_version,
      sid: idSesion,
    },
    process.env.JWT_SECRET,
    {
      algorithm: 'HS256',
      subject: String(usuario.id_usuario),
      issuer: 'petid-api',
      audience: 'petid-client',
      expiresIn: ACCESS_DURATION,
    }
  );
}

function empaquetarTokens(usuario, idSesion, refreshToken) {
  return {
    access_token: crearAccessToken(usuario, idSesion),
    refresh_token: refreshToken,
    token_type: 'Bearer',
    expires_in: 900,
  };
}

export async function crearSesionConTokens(
  usuario,
  agenteUsuario = ''
) {
  const idSesion = randomUUID();
  const refreshToken = crearRefreshToken(idSesion);

  await SesionUsuario.create({
    id_sesion: idSesion,
    id_usuario: usuario.id_usuario,
    refresh_hash: hashToken(refreshToken),
    agente_usuario: String(agenteUsuario).slice(0, 255),
    fecha_expiracion: new Date(
      Date.now() + SESSION_DURATION_MS
    ),
  });

  return empaquetarTokens(usuario, idSesion, refreshToken);
}

// =====================================
// RENOVAR CON ROTACIÓN
// =====================================

export async function renovarSesion(refreshToken) {
  const idSesion = extraerSesion(refreshToken);
  const hashRecibido = hashToken(refreshToken);

  let resultado;
  let comprometida = false;

  await sequelize.transaction(async (transaction) => {
    const sesion = await SesionUsuario.findByPk(idSesion, {
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!sesion) {
      return;
    }

    if (sesion.fecha_revocacion) {
      return;
    }

    const ahora = new Date();

    const expirada =
      sesion.fecha_expiracion <= ahora ||
      ahora.getTime() -
        new Date(sesion.ultimo_uso).getTime() >
          IDLE_DURATION_MS;

    if (expirada) {
      await sesion.update({
        fecha_revocacion: ahora,
      }, { transaction });

      return;
    }

    // ¿Es el refresh token actual?
    if (!hashIgual(sesion.refresh_hash, hashRecibido)) {
      // Comprobar si ya había sido utilizado.
      const usado = await RefreshTokenUsado.findByPk(
        hashRecibido,
        { transaction }
      );

      if (usado && usado.id_sesion === sesion.id_sesion) {
        await sesion.update({
          fecha_revocacion: ahora,
        }, { transaction });

        comprometida = true;
      }

      return;
    }

    const usuario = await Usuario.findByPk(
      sesion.id_usuario,
      { transaction }
    );

    if (
      !usuario ||
      !usuario.activo
    ) {
      await sesion.update({
        fecha_revocacion: ahora,
      }, { transaction });

      return;
    }

    // Guardar el hash anterior como consumido.
    await RefreshTokenUsado.create({
      token_hash: sesion.refresh_hash,
      id_sesion: sesion.id_sesion,
    }, { transaction });

    const nuevoRefresh = crearRefreshToken(sesion.id_sesion);

    await sesion.update({
      refresh_hash: hashToken(nuevoRefresh),
      ultimo_uso: ahora,
    }, { transaction });

    resultado = empaquetarTokens(
      usuario,
      sesion.id_sesion,
      nuevoRefresh
    );
  });

  if (comprometida) {
    throw new AppError(
      'Sesión revocada por reutilización de credenciales',
      401
    );
  }

  if (!resultado) {
    throw new AppError('Sesión inválida o expirada', 401);
  }

  return resultado;
}

// =====================================
// LISTAR SESIONES ACTIVAS
// =====================================

export async function listarSesiones(idUsuario) {
  const limiteInactividad = new Date(
    Date.now() - IDLE_DURATION_MS
  );

  return SesionUsuario.findAll({
    where: {
      id_usuario: idUsuario,
      fecha_revocacion: null,
      fecha_expiracion: { [Op.gt]: new Date() },
      ultimo_uso: { [Op.gt]: limiteInactividad },
    },
    attributes: [
      'id_sesion',
      'agente_usuario',
      'fecha_creacion',
      'ultimo_uso',
      'fecha_expiracion',
    ],
    order: [['ultimo_uso', 'DESC']],
  });
}

// =====================================
// CERRAR UNA SESIÓN
// =====================================

export async function cerrarSesion(idUsuario, idSesion) {
  await SesionUsuario.update(
    { fecha_revocacion: new Date() },
    {
      where: {
        id_usuario: idUsuario,
        id_sesion: idSesion,
        fecha_revocacion: null,
      },
    }
  );
}

// =====================================
// CERRAR TODAS LAS SESIONES
// =====================================

export async function cerrarTodasSesiones(idUsuario) {
  await SesionUsuario.update(
    { fecha_revocacion: new Date() },
    {
      where: {
        id_usuario: idUsuario,
        fecha_revocacion: null,
      },
    }
  );
}
