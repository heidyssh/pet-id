
import jwt from 'jsonwebtoken';

import {
  Usuario,
  SesionUsuario,
} from '../models/index.js';

const IDLE_DURATION_MS = 24 * 60 * 60 * 1000;

function noAutorizado(res) {
  return res.status(401).json({
    success: false,
    message: 'Sesión inválida o expirada',
  });
}

export async function verificarToken(req, res, next) {
  const authorization = req.headers.authorization;

  if (!/^Bearer\s+\S+$/i.test(authorization ?? '')) {
    return noAutorizado(res);
  }

  const token = authorization.split(/\s+/)[1];

  let payload;

  try {
    payload = jwt.verify(
      token,
      process.env.JWT_SECRET,
      {
        algorithms: ['HS256'],
        issuer: 'petid-api',
        audience: 'petid-client',
      }
    );
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      return noAutorizado(res);
    }

    return next(error);
  }

  if (
    !/^[1-9]\d*$/.test(String(payload.sub ?? '')) ||
    typeof payload.sid !== 'string' ||
    typeof payload.ver !== 'number'
  ) {
    return noAutorizado(res);
  }

  try {
    const sesion = await SesionUsuario.findOne({
      where: {
        id_sesion: payload.sid,
        id_usuario: payload.sub,
        fecha_revocacion: null,
      },
    });

    if (!sesion) {
      return noAutorizado(res);
    }

    const ahora = Date.now();

    if (
      new Date(sesion.fecha_expiracion).getTime() <= ahora ||
      ahora - new Date(sesion.ultimo_uso).getTime() >
        IDLE_DURATION_MS
    ) {
      return noAutorizado(res);
    }

    const usuario = await Usuario.findByPk(payload.sub);

    if (
      !usuario ||
      !usuario.activo ||
      !usuario.correo_verificado ||
      usuario.token_version !== payload.ver
    ) {
      return noAutorizado(res);
    }

    req.usuario = {
      id_usuario: usuario.id_usuario,
    };

    req.sesion = {
      id_sesion: sesion.id_sesion,
    };

    return next();
  } catch (error) {
    return next(error);
  }
}
