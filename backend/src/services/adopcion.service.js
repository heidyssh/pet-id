import { Op } from 'sequelize';
import { sequelize } from '../config/sequelize.js';
import {
  PublicacionAdopcion, SolicitudAdopcion, Mascota,
  Organizacion, UsuarioOrganizacion, Usuario, FotoMascota,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';
import { crearNotificacion } from './notificacion.service.js';

const incluirPublicacion = [
  {
    model: Mascota, as: 'mascota',
    attributes: ['id_mascota', 'nombre', 'id_especie', 'id_raza', 'sexo', 'color_principal', 'tamano', 'senas_particulares'],
    include: [{ model: FotoMascota, as: 'fotos', attributes: ['url_original', 'url_recorte', 'es_principal'], required: false }],
  },
  { model: Organizacion, as: 'organizacion', attributes: ['id_organizacion', 'nombre', 'tipo'], required: false },
];

async function puedeGestionar(publicacion, idUsuario, transaction) {
  const mascota = await Mascota.findByPk(publicacion.id_mascota, { transaction });
  if (String(mascota.id_dueno) === String(idUsuario)) return mascota;
  if (publicacion.id_organizacion) {
    const membresia = await UsuarioOrganizacion.findOne({
      where: { id_usuario: idUsuario, id_organizacion: publicacion.id_organizacion, activo: true },
      transaction,
    });
    if (membresia) return mascota;
  }
  throw new AppError('Publicación no encontrada', 404);
}

export async function crearPublicacion(datos, idUsuario) {
  return sequelize.transaction(async (transaction) => {
    const mascota = await Mascota.findByPk(datos.id_mascota, { transaction, lock: transaction.LOCK.UPDATE });
    if (!mascota) throw new AppError('Mascota no encontrada', 404);
    let autorizado = String(mascota.id_dueno) === String(idUsuario);
    if (datos.id_organizacion) {
      const organizacion = await Organizacion.findOne({
        where: { id_organizacion: datos.id_organizacion, verificada: true }, transaction,
      });
      const membresia = organizacion && await UsuarioOrganizacion.findOne({
        where: { id_usuario: idUsuario, id_organizacion: datos.id_organizacion, activo: true }, transaction,
      });
      autorizado ||= Boolean(membresia);
      if (!organizacion || !membresia) throw new AppError('Organización no disponible', 403);
    }
    if (!autorizado) throw new AppError('Mascota no encontrada', 404);
    if (mascota.estado === 'perdido') throw new AppError('Una mascota perdida no puede publicarse en adopción', 409);
    try {
      const publicacion = await PublicacionAdopcion.create({
        id_mascota: mascota.id_mascota,
        id_organizacion: datos.id_organizacion ?? null,
        descripcion: datos.descripcion,
        estado: 'disponible',
      }, { transaction });
      await mascota.update({ estado: 'en_adopcion' }, { transaction });
      return publicacion;
    } catch (error) {
      if (error.name === 'SequelizeUniqueConstraintError') throw new AppError('La mascota ya tiene una publicación activa', 409);
      throw error;
    }
  });
}

export async function listarPublicaciones() {
  return PublicacionAdopcion.findAll({
    where: { estado: 'disponible' }, include: incluirPublicacion,
    order: [['fecha_publicacion', 'DESC']],
  });
}

export async function detallePublicacion(idPublicacion) {
  if (!validarIdPositivo(idPublicacion)) throw new AppError('Identificador inválido', 400);
  const item = await PublicacionAdopcion.findOne({
    where: { id_publicacion: idPublicacion, estado: 'disponible' }, include: incluirPublicacion,
  });
  if (!item) throw new AppError('Publicación no encontrada', 404);
  return item;
}

export async function solicitarAdopcion(idPublicacion, idUsuario, mensaje) {
  const publicacion = await PublicacionAdopcion.findOne({
    where: { id_publicacion: idPublicacion, estado: 'disponible' },
    include: [{ model: Mascota, as: 'mascota', attributes: ['id_dueno'] }],
  });
  if (!publicacion) throw new AppError('Publicación no encontrada', 404);
  if (String(publicacion.mascota.id_dueno) === String(idUsuario)) throw new AppError('No puede solicitar su propia mascota', 409);
  try {
    const solicitud = await SolicitudAdopcion.create({ id_publicacion: idPublicacion, id_usuario: idUsuario, mensaje: mensaje ?? null });
    await crearNotificacion({
      id_usuario: publicacion.mascota.id_dueno,
      tipo: 'solicitud_adopcion_nueva',
      titulo: 'Nueva solicitud de adopción',
      mensaje: 'Recibiste una nueva solicitud para una publicación de adopción.',
      datos: { id_publicacion: idPublicacion, id_solicitud: solicitud.id_solicitud },
    });
    return solicitud;
  } catch (error) {
    if (error.name === 'SequelizeUniqueConstraintError') throw new AppError('Ya existe una solicitud para esta publicación', 409);
    throw error;
  }
}

export async function misSolicitudes(idUsuario) {
  return SolicitudAdopcion.findAll({
    where: { id_usuario: idUsuario },
    include: [{ model: PublicacionAdopcion, as: 'publicacion', include: incluirPublicacion }],
    order: [['fecha_solicitud', 'DESC']],
  });
}

export async function solicitudesPublicacion(idPublicacion, idUsuario) {
  const publicacion = await PublicacionAdopcion.findByPk(idPublicacion);
  if (!publicacion) throw new AppError('Publicación no encontrada', 404);
  await puedeGestionar(publicacion, idUsuario);
  return SolicitudAdopcion.findAll({
    where: { id_publicacion: idPublicacion },
    include: [{ model: Usuario, as: 'solicitante', attributes: ['id_usuario', 'nombre', 'apellido', 'correo', 'telefono'] }],
    order: [['fecha_solicitud', 'ASC']],
  });
}

export async function revisarSolicitud(idSolicitud, idUsuario, estado) {
  const solicitud = await sequelize.transaction(async (transaction) => {
    const solicitud = await SolicitudAdopcion.findByPk(idSolicitud, { transaction, lock: transaction.LOCK.UPDATE });
    if (!solicitud) throw new AppError('Solicitud no encontrada', 404);
    const publicacion = await PublicacionAdopcion.findByPk(solicitud.id_publicacion, { transaction, lock: transaction.LOCK.UPDATE });
    await puedeGestionar(publicacion, idUsuario, transaction);
    if (solicitud.estado !== 'pendiente' || publicacion.estado !== 'disponible') throw new AppError('La solicitud ya no puede revisarse', 409);
    await solicitud.update({ estado }, { transaction });
    if (estado === 'aprobada') {
      await PublicacionAdopcion.update({ estado: 'cerrada' }, { where: { id_publicacion: publicacion.id_publicacion }, transaction });
      await SolicitudAdopcion.update({ estado: 'rechazada' }, {
        where: { id_publicacion: publicacion.id_publicacion, id_solicitud: { [Op.ne]: solicitud.id_solicitud }, estado: 'pendiente' }, transaction,
      });
    }
    return solicitud;
  });

  await crearNotificacion({
    id_usuario: solicitud.id_usuario,
    tipo: 'solicitud_adopcion_actualizada',
    titulo: 'Solicitud de adopción actualizada',
    mensaje: `Tu solicitud fue ${estado}.`,
    datos: { id_solicitud: solicitud.id_solicitud, estado },
  });

  return solicitud;
}

export async function cancelarSolicitud(idSolicitud, idUsuario) {
  const [cantidad] = await SolicitudAdopcion.update({ estado: 'cancelada' }, {
    where: { id_solicitud: idSolicitud, id_usuario: idUsuario, estado: 'pendiente' },
  });
  if (!cantidad) throw new AppError('Solicitud no encontrada o no cancelable', 404);
}

export async function cerrarPublicacion(idPublicacion, idUsuario, estado) {
  return sequelize.transaction(async (transaction) => {
    const publicacion = await PublicacionAdopcion.findByPk(idPublicacion, { transaction, lock: transaction.LOCK.UPDATE });
    if (!publicacion) throw new AppError('Publicación no encontrada', 404);
    const mascota = await puedeGestionar(publicacion, idUsuario, transaction);
    if (publicacion.estado !== 'disponible') throw new AppError('La publicación ya está cerrada', 409);
    await publicacion.update({ estado }, { transaction });
    await SolicitudAdopcion.update({ estado: 'rechazada' }, { where: { id_publicacion: idPublicacion, estado: 'pendiente' }, transaction });
    await mascota.update({ estado: 'a_salvo' }, { transaction });
    return publicacion;
  });
}
