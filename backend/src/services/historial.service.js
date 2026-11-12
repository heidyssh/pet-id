import {
  HistorialClinico, Mascota, Organizacion, Usuario,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import { validarIdPositivo } from '../utils/ubicacion.js';

function validarFecha(datos) {
  if (datos.proxima_fecha && datos.fecha_aplicacion && datos.proxima_fecha < datos.fecha_aplicacion) {
    throw new AppError('La próxima fecha no puede ser anterior a la aplicación', 400);
  }
}

export async function crearRegistroClinico(datos, idMascota, organizacion, idUsuario) {
  if (!validarIdPositivo(idMascota)) throw new AppError('Mascota inválida', 400);
  const mascota = await Mascota.findByPk(idMascota);
  if (!mascota) throw new AppError('Mascota no encontrada', 404);
  validarFecha(datos);
  return HistorialClinico.create({
    ...datos,
    proxima_fecha: datos.proxima_fecha ?? null,
    id_mascota: idMascota,
    id_organizacion: organizacion.id_organizacion,
    id_usuario_registro: idUsuario,
  });
}

export async function historialDeMascota(idMascota, idUsuario) {
  if (!validarIdPositivo(idMascota)) throw new AppError('Mascota inválida', 400);
  const mascota = await Mascota.findOne({
    where: { id_mascota: idMascota, id_dueno: idUsuario },
    attributes: ['id_mascota', 'nombre'],
  });
  if (!mascota) throw new AppError('Mascota no encontrada', 404);
  const items = await HistorialClinico.findAll({
    where: { id_mascota: idMascota },
    attributes: ['id_historial', 'tipo_registro', 'descripcion', 'fecha_aplicacion', 'proxima_fecha'],
    include: [
      { model: Organizacion, as: 'organizacion', attributes: ['id_organizacion', 'nombre', 'tipo'], required: false },
      { model: Usuario, as: 'registradoPor', attributes: ['id_usuario', 'nombre', 'apellido'] },
    ],
    order: [['fecha_aplicacion', 'DESC'], ['id_historial', 'DESC']],
  });
  return { mascota, items, sincronizado_en: new Date().toISOString() };
}

export async function actualizarRegistroClinico(idHistorial, idOrganizacion, datos) {
  if (!validarIdPositivo(idHistorial)) throw new AppError('Registro inválido', 400);
  const registro = await HistorialClinico.findOne({
    where: { id_historial: idHistorial, id_organizacion: idOrganizacion },
  });
  if (!registro) throw new AppError('Registro clínico no encontrado', 404);
  validarFecha({
    fecha_aplicacion: datos.fecha_aplicacion ?? registro.fecha_aplicacion,
    proxima_fecha: datos.proxima_fecha === undefined ? registro.proxima_fecha : datos.proxima_fecha,
  });
  await registro.update(datos);
  return registro;
}
