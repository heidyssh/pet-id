import jwt from 'jsonwebtoken';
import { SesionUsuario, Usuario } from '../models/index.js';

export async function autenticarSocket(socket, next) {
  try {
    const token = socket.handshake.auth?.token;
    const payload = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256'], issuer: 'petid-api', audience: 'petid-client',
    });
    const [usuario, sesion] = await Promise.all([
      Usuario.findByPk(payload.sub),
      SesionUsuario.findOne({ where: { id_sesion: payload.sid, id_usuario: payload.sub, fecha_revocacion: null } }),
    ]);
    if (!usuario?.activo || !usuario.correo_verificado || !sesion || usuario.token_version !== payload.ver) {
      return next(new Error('no autorizado'));
    }
    socket.data.id_usuario = usuario.id_usuario;
    return next();
  } catch {
    return next(new Error('no autorizado'));
  }
}

export function conectarSocket(socket) {
  socket.join(`usuario:${socket.data.id_usuario}`);
}
