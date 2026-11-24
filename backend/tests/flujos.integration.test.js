import assert from 'node:assert/strict';
import { once } from 'node:events';
import { unlink } from 'node:fs/promises';
import { createServer } from 'node:http';
import path from 'node:path';
import sharp from 'sharp';

import { app } from '../src/app.js';
import { sequelize } from '../src/config/sequelize.js';
import * as modelos from '../src/models/index.js';
import { crearSesionConTokens } from '../src/services/sesion.service.js';
import { actualizarPerfil, registrarUsuario } from '../src/services/auth.service.js';
import { crearMascota } from '../src/services/mascota.service.js';
import { crearReporteExtravio, obtenerExtravioPublico, resolverExtravio } from '../src/services/extravio.service.js';
import { crearAvistamiento, obtenerAvistamiento } from '../src/services/avistamiento.service.js';
import { listarCoincidenciasReporte } from '../src/services/coincidencia.service.js';
import { agregarFotoMascota, agregarFotoAvistamiento } from '../src/services/foto.service.js';
import { crearOrganizacion, guardarMembresia, verificarOrganizacion } from '../src/services/organizacion.service.js';
import {
  crearRegistroClinico, crearRegistroClinicoPropio, historialDeMascota,
} from '../src/services/historial.service.js';
import { crearPublicacion, solicitarAdopcion, revisarSolicitud } from '../src/services/adopcion.service.js';
import {
  actualizarUbicacionAlertas, obtenerUbicacionAlertas,
} from '../src/services/alertaUbicacion.service.js';
import { registrarDispositivoPush, eliminarDispositivoPush } from '../src/services/push.service.js';

const sufijo = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const correos = [`prueba-a-${sufijo}@petid.local`, `prueba-b-${sufijo}@petid.local`];
const archivos = [];
let usuarios = [];
let servidor;

try {
  usuarios = await modelos.Usuario.bulkCreate(correos.map((correo, indice) => ({
    nombre: `Prueba${indice}`,
    apellido: 'Integración',
    correo,
    telefono: `+5049000000${indice + 1}`,
    password_hash: 'hash-no-utilizado',
    activo: true,
    correo_verificado: true,
  })), { returning: true });

  await assert.rejects(
    () => registrarUsuario({
      nombre: 'Correo', apellido: 'Duplicado', correo: correos[0],
      telefono: '+50490000009', password: 'PetId123!',
    }),
    /correo ya está registrado/i
  );
  await assert.rejects(
    () => registrarUsuario({
      nombre: 'Telefono', apellido: 'Duplicado',
      correo: `telefono-${sufijo}@petid.local`,
      telefono: '+50490000001', password: 'PetId123!',
    }),
    /teléfono ya está registrado/i
  );

  const rol = await modelos.Rol.findOne({ where: { nombre: 'ciudadano' } });
  await modelos.UsuarioRol.bulkCreate(usuarios.map((usuario) => ({ id_usuario: usuario.id_usuario, id_rol: rol.id_rol })));

  const tokenPushPrueba = `token-push-prueba-${sufijo}-suficientemente-largo`;
  const dispositivo = await registrarDispositivoPush(usuarios[1].id_usuario, {
    token: tokenPushPrueba,
    plataforma: 'android',
  });
  assert.equal(dispositivo.plataforma, 'android');
  await eliminarDispositivoPush(usuarios[1].id_usuario, tokenPushPrueba);
  assert.equal(await modelos.DispositivoPush.count({ where: { token: tokenPushPrueba } }), 0);

  const tokens = await crearSesionConTokens(usuarios[0], 'prueba integrada');
  assert.ok(tokens.access_token && tokens.refresh_token);

  const perfilActualizado = await actualizarPerfil(usuarios[0].id_usuario, {
    nombre: 'PerfilPrueba',
    telefono: '+50499999991',
  });
  assert.equal(perfilActualizado.nombre, 'PerfilPrueba');
  assert.equal(perfilActualizado.telefono, '+50499999991');
  await assert.rejects(
    actualizarPerfil(usuarios[1].id_usuario, { telefono: '+50499999991' }),
    /teléfono ya está registrado/i
  );

  const mascota = await crearMascota({
    nombre: 'Luna', id_especie: 1, color_principal: 'café', tamano: 'mediano',
    senas_particulares: 'mancha blanca',
  }, usuarios[0].id_usuario);

  await actualizarUbicacionAlertas(usuarios[1].id_usuario, {
    ubicacion: { latitud: 15.7836, longitud: -86.7917 },
    radio_km: 10,
  });
  const ubicacionAlertas = await obtenerUbicacionAlertas(usuarios[1].id_usuario);
  assert.equal(ubicacionAlertas.activa, true);
  assert.equal(ubicacionAlertas.radio_km, 10);
  assert.ok(ubicacionAlertas.ubicacion?.latitud);

  const reporte = await crearReporteExtravio({
    id_mascota: mascota.id_mascota,
    fecha_perdida: new Date(Date.now() - 3600000).toISOString(),
    ubicacion: { latitud: 15.7835, longitud: -86.7918 }, radio_km: 5,
  }, usuarios[0].id_usuario);
  assert.equal(await modelos.AlertaExtravioEnviada.count({
    where: { id_usuario: usuarios[1].id_usuario, id_reporte: reporte.id_reporte },
  }), 1);
  assert.ok(await modelos.Notificacion.findOne({
    where: { id_usuario: usuarios[1].id_usuario, tipo: 'extravio_cercano' },
  }));
  const segundaActualizacion = await actualizarUbicacionAlertas(usuarios[1].id_usuario, {
    ubicacion: { latitud: 15.7836, longitud: -86.7917 },
    radio_km: 10,
  });
  assert.equal(segundaActualizacion.alertas_nuevas, 0);

  const avistamiento = await crearAvistamiento({
    id_especie: 1,
    fecha_avistamiento: new Date().toISOString(),
    ubicacion: { latitud: 15.7836, longitud: -86.7917 },
    color_principal: 'café', tamano: 'mediano',
    senas_particulares: 'mancha blanca', descripcion: 'Perro con mancha blanca',
  }, usuarios[1].id_usuario);
  assert.equal(await modelos.Coincidencia.count({ where: { id_avistamiento: avistamiento.id_avistamiento } }), 1);
  const coincidenciasDueno = await listarCoincidenciasReporte(
    reporte.id_reporte,
    usuarios[0].id_usuario
  );
  assert.equal(
    coincidenciasDueno[0].avistamiento.ubicacion.latitud,
    15.7836
  );
  await assert.rejects(
    () => listarCoincidenciasReporte(
      reporte.id_reporte,
      usuarios[1].id_usuario
    ),
    /Reporte no encontrado/
  );

  const buffer = await sharp({ create: { width: 20, height: 20, channels: 3, background: '#8b5a2b' } }).png().toBuffer();
  const foto = await agregarFotoMascota(mascota.id_mascota, usuarios[0].id_usuario, { buffer }, true);
  assert.ok(
    ['proveedor_no_configurado', 'animal_no_detectado'].includes(
      foto.procesamiento
    ),
    `Estado visual inesperado: ${foto.procesamiento}`
  );
  archivos.push(...[foto.url_original, foto.url_recorte].filter(Boolean));
  const fotoAvistamiento = await agregarFotoAvistamiento(
    avistamiento.id_avistamiento,
    usuarios[1].id_usuario,
    { buffer },
    'lejos'
  );
  archivos.push(...[fotoAvistamiento.url_original, fotoAvistamiento.url_recorte].filter(Boolean));
  const detalleReporte = await obtenerExtravioPublico(reporte.id_reporte);
  assert.equal(detalleReporte.mascota.fotos.length, 1);
  const detalleAvistamiento = await obtenerAvistamiento(avistamiento.id_avistamiento);
  assert.equal(detalleAvistamiento.fotos.length, 1);
  servidor = createServer(app);
  servidor.listen(0, '127.0.0.1');
  await once(servidor, 'listening');
  const { port } = servidor.address();
  if (foto.url_original.startsWith('https://')) {
    assert.match(foto.url_original, /^https:\/\/res\.cloudinary\.com\//);
  } else {
    const respuestaFoto = await fetch(
      `http://127.0.0.1:${port}${foto.url_original}`
    );
    assert.equal(respuestaFoto.status, 200);
    assert.equal(
      respuestaFoto.headers.get('cross-origin-resource-policy'),
      'cross-origin'
    );
  }

  await resolverExtravio(reporte.id_reporte, usuarios[0].id_usuario);
  const organizacion = await crearOrganizacion({ nombre: 'Veterinaria de prueba', tipo: 'veterinaria', cargo: 'administrador' }, usuarios[0].id_usuario);
  await verificarOrganizacion(String(organizacion.id_organizacion), true);
  const rolVeterinario = await modelos.Rol.findOne({ where: { nombre: 'personal_veterinario' } });
  assert.ok(await modelos.UsuarioRol.findOne({
    where: { id_usuario: usuarios[0].id_usuario, id_rol: rolVeterinario.id_rol },
  }));
  await guardarMembresia(organizacion.id_organizacion, {
    id_usuario: usuarios[1].id_usuario,
    cargo: 'asistente',
    activo: true,
  });
  assert.ok(await modelos.UsuarioRol.findOne({
    where: { id_usuario: usuarios[1].id_usuario, id_rol: rolVeterinario.id_rol },
  }));
  await crearRegistroClinico({ tipo_registro: 'vacuna', descripcion: 'Vacuna de prueba', fecha_aplicacion: '2026-11-11' }, mascota.id_mascota, organizacion, usuarios[0].id_usuario);
  const registroPropio = await crearRegistroClinicoPropio({
    tipo_registro: 'desparasitacion',
    descripcion: 'Registro del propietario',
    fecha_aplicacion: '2026-11-12',
  }, mascota.id_mascota, usuarios[0].id_usuario);
  assert.equal(registroPropio.id_organizacion, null);
  await assert.rejects(
    crearRegistroClinicoPropio({
      tipo_registro: 'vacuna',
      descripcion: 'Intento sin autorizacion',
      fecha_aplicacion: '2026-11-12',
    }, mascota.id_mascota, usuarios[1].id_usuario),
    (error) => error.statusCode === 404
  );
  const historial = await historialDeMascota(String(mascota.id_mascota), usuarios[0].id_usuario);
  assert.equal(historial.items.length, 2);

  const publicacion = await crearPublicacion({ id_mascota: mascota.id_mascota, descripcion: 'Mascota de prueba disponible para un hogar responsable.' }, usuarios[0].id_usuario);
  const solicitud = await solicitarAdopcion(publicacion.id_publicacion, usuarios[1].id_usuario, 'Solicitud de prueba');
  await revisarSolicitud(solicitud.id_solicitud, usuarios[0].id_usuario, 'aprobada');
  assert.equal((await publicacion.reload()).estado, 'cerrada');

  console.log('Flujo integrado PetID: OK');
} finally {
  if (servidor?.listening) {
    await new Promise((resolve) => servidor.close(resolve));
  }
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
