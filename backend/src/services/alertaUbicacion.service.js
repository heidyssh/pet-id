import { QueryTypes } from 'sequelize';

import { sequelize } from '../config/sequelize.js';
import {
  SuscripcionUbicacion,
  AlertaExtravioEnviada,
} from '../models/index.js';
import { crearPuntoGeografico } from '../utils/ubicacion.js';
import { crearNotificacion } from './notificacion.service.js';

async function notificarSiEsNueva(candidato) {
  return sequelize.transaction(async (transaction) => {
    const [alerta, creada] = await AlertaExtravioEnviada.findOrCreate({
      where: {
        id_usuario: candidato.id_usuario,
        id_reporte: candidato.id_reporte,
      },
      defaults: { fecha_envio: new Date() },
      transaction,
    });
    if (!creada) return false;

    await crearNotificacion({
      id_usuario: candidato.id_usuario,
      tipo: 'extravio_cercano',
      titulo: 'Mascota extraviada cerca de ti',
      mensaje: `${candidato.nombre} fue reportada como perdida en una zona cercana.`,
      datos: {
        id_reporte: candidato.id_reporte,
        referencia_lugar: candidato.referencia_lugar,
        distancia_km: Number(Number(candidato.distancia_km).toFixed(2)),
      },
    }, transaction);
    return Boolean(alerta);
  });
}

async function enviarCandidatos(candidatos) {
  let enviadas = 0;
  for (const candidato of candidatos) {
    if (await notificarSiEsNueva(candidato)) enviadas += 1;
  }
  return enviadas;
}

export async function guardarUbicacionAlertas(idUsuario, datos, transaction) {
  const [suscripcion] = await SuscripcionUbicacion.upsert({
    id_usuario: idUsuario,
    ubicacion: crearPuntoGeografico(datos.ubicacion),
    radio_km: datos.radio_km,
    activa: true,
    fecha_actualizacion: new Date(),
  }, { returning: true, transaction });
  return suscripcion;
}

export async function actualizarUbicacionAlertas(idUsuario, datos) {
  const suscripcion = await guardarUbicacionAlertas(idUsuario, datos);
  const candidatos = await sequelize.query(`
    SELECT
      :id_usuario::bigint AS id_usuario,
      r.id_reporte,
      r.referencia_lugar,
      m.nombre,
      ST_Distance(s.ubicacion, r.ubicacion) / 1000 AS distancia_km
    FROM suscripciones_ubicacion s
    JOIN reportes_extravio r ON r.estado = 'activo' AND r.ubicacion IS NOT NULL
    JOIN mascotas m ON m.id_mascota = r.id_mascota
    WHERE s.id_usuario = :id_usuario
      AND s.activa = true
      AND m.id_dueno <> :id_usuario
      AND ST_DWithin(s.ubicacion, r.ubicacion, s.radio_km * 1000)
  `, {
    replacements: { id_usuario: idUsuario },
    type: QueryTypes.SELECT,
  });

  const alertasNuevas = await enviarCandidatos(candidatos);
  return {
    activa: suscripcion.activa,
    radio_km: Number(suscripcion.radio_km),
    fecha_actualizacion: suscripcion.fecha_actualizacion,
    alertas_nuevas: alertasNuevas,
  };
}

export async function desactivarUbicacionAlertas(idUsuario) {
  await SuscripcionUbicacion.destroy({ where: { id_usuario: idUsuario } });
}

export async function obtenerUbicacionAlertas(idUsuario) {
  const suscripcion = await SuscripcionUbicacion.findByPk(idUsuario);
  if (!suscripcion) return { activa: false };
  const coordenadas = suscripcion.ubicacion?.coordinates;
  return {
    activa: suscripcion.activa,
    radio_km: Number(suscripcion.radio_km),
    fecha_actualizacion: suscripcion.fecha_actualizacion,
    ubicacion: Array.isArray(coordenadas)
      ? { longitud: coordenadas[0], latitud: coordenadas[1] }
      : null,
  };
}

export async function notificarSuscriptoresCercanos(idReporte) {
  const candidatos = await sequelize.query(`
    SELECT
      s.id_usuario,
      r.id_reporte,
      r.referencia_lugar,
      m.nombre,
      ST_Distance(s.ubicacion, r.ubicacion) / 1000 AS distancia_km
    FROM reportes_extravio r
    JOIN mascotas m ON m.id_mascota = r.id_mascota
    JOIN suscripciones_ubicacion s
      ON s.activa = true
     AND s.fecha_actualizacion >= NOW() - INTERVAL '24 hours'
     AND s.id_usuario <> m.id_dueno
     AND r.ubicacion IS NOT NULL
     AND ST_DWithin(s.ubicacion, r.ubicacion, s.radio_km * 1000)
    WHERE r.id_reporte = :id_reporte
      AND r.estado = 'activo'
  `, {
    replacements: { id_reporte: idReporte },
    type: QueryTypes.SELECT,
  });
  return enviarCandidatos(candidatos);
}
