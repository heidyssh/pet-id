
import jwt from 'jsonwebtoken';
import { Usuario } from '../models/index.js';

export async function verificarToken(req, res, next) {
  const authorization = req.headers.authorization;

  if (!authorization?.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Autenticación requerida',
    });
  }

  const token = authorization.slice(7).trim();

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Autenticación requerida',
    });
  }

  try {
    const payload = jwt.verify(
      token,
      process.env.JWT_SECRET,
      {
        algorithms: ['HS256'],
        issuer: 'petid-api',
        audience: 'petid-client',
      }
    );

    if (!payload.sub || !/^[0-9]+$/.test(payload.sub)) {
      return res.status(401).json({
        success: false,
        message: 'Token inválido o expirado',
      });
    }

    const usuario = await Usuario.findByPk(payload.sub);

    if (!usuario || !usuario.activo) {
      return res.status(401).json({
        success: false,
        message: 'Token inválido o expirado',
      });
    }

    req.usuario = {
      id_usuario: usuario.id_usuario,
    };

    return next();
  } catch (error) {
    if (
      error instanceof jwt.JsonWebTokenError ||
      error instanceof jwt.TokenExpiredError
    ) {
      return res.status(401).json({
        success: false,
        message: 'Token inválido o expirado',
      });
    }

    return next(error);
  }
}
