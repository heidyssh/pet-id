import assert from 'node:assert/strict';
import { unlink } from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

import { sequelize } from '../src/config/sequelize.js';
import * as modelos from '../src/models/index.js';
import { crearSesionConTokens } from '../src/services/sesion.service.js';
import { crearMascota } from '../src/services/mascota.service.js';
import { crearReporteExtravio, resolverExtravio } from '../src/services/extravio.service.js';
import { crearAvistamiento } from '../src/services/avistamiento.service.js';
import { agregarFotoMascota } from '../src/services/foto.service.js';
import { crearOrganizacion, verificarOrganizacion } from '../src/services/organizacion.service.js';
import { crearRegistroClinico, historialDeMascota } from '../src/services/historial.service.js';
import { crearPublicacion, solicitarAdopcion, revisarSolicitud } from '../src/services/adopcion.service.js';

const sufijo = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const correos = [`prueba-a-${sufijo}@petid.local`, `prueba-b-${sufijo}@petid.local`];
const archivos = [];
let usuarios = [];

try {
  usuarios = await modelos.Usuario.bulkCreate(correos.map((correo, indice) => ({
    nombre: `Prueba${indice}`,
    apellido: 'Integración',
    correo,
    password_hash: 'hash-no-utilizado',
    activo: true,
    correo_verificado: true,
  })), { returning: true });

  const rol = await modelos.Rol.findOne({ where: { nombre: 'ciudadano' } });
  await modelos.UsuarioRol.bulkCreate(usuarios.map((usuario) => ({ id_usuario: usuario.id_usuario, id_rol: rol.id_rol })));

  const tokens = await crearSesionConTokens(usuarios[0], 'prueba integrada');
  assert.ok(tokens.access_token && tokens.refresh_token);

  const mascota = await crearMascota({
    nombre: 'Luna', id_especie: 1, color_principal: 'café', tamano: 'mediano',
    senas_particulares: 'mancha blanca',
  }, usuarios[0].id_usuario);

  const reporte = await crearReporteExtravio({
    id_mascota: mascota.id_mascota,
    fecha_perdida: new Date(Date.now() - 3600000).toISOString(),
    ubicacion: { latitud: 15.7835, longitud: -86.7918 }, radio_km: 5,
  }, usuarios[0].id_usuario);

  const avistamiento = await crearAvistamiento({
    id_especie: 1,
    fecha_avistamiento: new Date().toISOString(),
    ubicacion: { latitud: 15.7836, longitud: -86.7917 },
    color_principal: 'café', tamano: 'mediano',
    senas_particulares: 'mancha blanca', descripcion: 'Perro con mancha blanca',
  }, usuarios[1].id_usuario);
  assert.equal(await modelos.Coincidencia.count({ where: { id_avistamiento: avistamiento.id_avistamiento } }), 1);

  const buffer = await sharp({ create: { width: 20, height: 20, channels: 3, background: '#8b5a2b' } }).png().toBuffer();
  const foto = await agregarFotoMascota(mascota.id_mascota, usuarios[0].id_usuario, { buffer }, true);
  assert.equal(foto.procesamiento, 'proveedor_no_configurado');
  archivos.push(...[foto.url_original, foto.url_recorte].filter(Boolean));

  await resolverExtravio(reporte.id_reporte, usuarios[0].id_usuario);
  const organizacion = await crearOrganizacion({ nombre: 'Veterinaria de prueba', tipo: 'veterinaria', cargo: 'administrador' }, usuarios[0].id_usuario);
  await verificarOrganizacion(String(organizacion.id_organizacion), true);
  await crearRegistroClinico({ tipo_registro: 'vacuna', descripcion: 'Vacuna de prueba', fecha_aplicacion: '2026-11-11' }, mascota.id_mascota, organizacion, usuarios[0].id_usuario);
  const historial = await historialDeMascota(String(mascota.id_mascota), usuarios[0].id_usuario);
  assert.equal(historial.items.length, 1);

  const publicacion = await crearPublicacion({ id_mascota: mascota.id_mascota, descripcion: 'Mascota de prueba disponible para un hogar responsable.' }, usuarios[0].id_usuario);
  const solicitud = await solicitarAdopcion(publicacion.id_publicacion, usuarios[1].id_usuario, 'Solicitud de prueba');
  await revisarSolicitud(solicitud.id_solicitud, usuarios[0].id_usuario, 'aprobada');
  assert.equal((await publicacion.reload()).estado, 'cerrada');

  console.log('Flujo integrado PetID: OK');
} finally {
  if (usuarios.length) {
    const ids = usuarios.map((usuario) => usuario.id_usuario);
    await modelos.SolicitudAdopcion.destroy({ where: { id_usuario: ids } });
    const mascotas = await modelos.Mascota.findAll({ where: { id_dueno: ids }, attributes: ['id_mascota'] });
    const idsMascota = mascotas.map((item) => item.id_mascota);
    if (idsMascota.length) {
      await modelos.PublicacionAdopcion.destroy({ where: { id_mascota: idsMascota } });
      await modelos.HistorialClinico.destroy({ where: { id_mascota: idsMascota } });
      const reportes = await modelos.ReporteExtravio.findAll({ where: { id_mascota: idsMascota }, attributes: ['id_reporte'] });
      await modelos.Coincidencia.destroy({ where: { id_reporte: reportes.map((item) => item.id_reporte) } });
      await modelos.ReporteExtravio.destroy({ where: { id_mascota: idsMascota } });
      await modelos.FotoMascota.destroy({ where: { id_mascota: idsMascota } });
      await modelos.Mascota.destroy({ where: { id_mascota: idsMascota } });
    }
    const avistamientos = await modelos.Avistamiento.findAll({ where: { id_usuario: ids }, attributes: ['id_avistamiento'] });
    await modelos.Coincidencia.destroy({ where: { id_avistamiento: avistamientos.map((item) => item.id_avistamiento) } });
    await modelos.Avistamiento.destroy({ where: { id_usuario: ids } });
    await modelos.UsuarioOrganizacion.destroy({ where: { id_usuario: ids } });
    await modelos.Organizacion.destroy({ where: { nombre: 'Veterinaria de prueba' } });
    await modelos.SesionUsuario.destroy({ where: { id_usuario: ids } });
    await modelos.UsuarioRol.destroy({ where: { id_usuario: ids } });
    await modelos.Usuario.destroy({ where: { id_usuario: ids } });
  }
  await Promise.allSettled(archivos.filter(Boolean).map((url) => unlink(path.resolve(process.cwd(), `.${url}`))));
  await sequelize.close();
}
