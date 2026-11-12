import { Notificacion } from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';
import { emitirAUsuario } from './realtime.service.js';

export async function crearNotificacion(datos, transaction) {
  const item = await Notificacion.create(datos, { transaction });
  emitirAUsuario(datos.id_usuario, 'notificacion:nueva', item.toJSON());
  return item;
}

export async function listarNotificaciones(idUsuario, { pagina = 1, limite = 20, soloNoLeidas = false }) {
  const where = { id_usuario: idUsuario };
  if (soloNoLeidas) where.leida = false;
  const { count, rows } = await Notificacion.findAndCountAll({
    where,
    order: [['fecha_creacion', 'DESC'], ['id_notificacion', 'DESC']],
    limit: limite,
    offset: (pagina - 1) * limite,
  });
  return {
    items: rows,
    paginacion: { pagina, limite, total: count, total_paginas: Math.ceil(count / limite) },
  };
}

export async function marcarLeida(idNotificacion, idUsuario) {
  if (!validarIdPositivo(idNotificacion)) throw new AppError('Identificador inválido', 400);
  const [cantidad] = await Notificacion.update({ leida: true }, {
    where: { id_notificacion: idNotificacion, id_usuario: idUsuario },
  });
  if (!cantidad) throw new AppError('Notificación no encontrada', 404);
}
