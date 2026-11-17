import assert from 'node:assert/strict';
import { once } from 'node:events';
import { readFile, unlink } from 'node:fs/promises';
import { createServer } from 'node:http';
import path from 'node:path';

import { app } from '../src/app.js';
import { sequelize } from '../src/config/sequelize.js';
import * as modelos from '../src/models/index.js';
import { crearSesionConTokens } from '../src/services/sesion.service.js';
import { crearMascota } from '../src/services/mascota.service.js';
import { crearReporteExtravio } from '../src/services/extravio.service.js';
import { agregarFotoMascota } from '../src/services/foto.service.js';

const rutaImagen = process.env.PETID_TEST_IMAGE;
if (!rutaImagen) throw new Error('Defina PETID_TEST_IMAGE con una imagen de perro o gato');

let usuario;
let mascota;
let reporte;
let foto;
let avistamientoEscaneo;
let fotoEscaneo;
let servidor;

try {
  const sufijo = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  usuario = await modelos.Usuario.create({
    nombre: 'Prueba',
    apellido: 'Visual',
    correo: `visual-${sufijo}@petid.local`,
    password_hash: 'hash-no-utilizado',
    activo: true,
    correo_verificado: true,
  });
  const rol = await modelos.Rol.findOne({ where: { nombre: 'ciudadano' } });
  await modelos.UsuarioRol.create({ id_usuario: usuario.id_usuario, id_rol: rol.id_rol });
  const tokens = await crearSesionConTokens(usuario, 'prueba visual e2e');

  mascota = await crearMascota({
    nombre: 'Golden de prueba',
    id_especie: 1,
    color_principal: 'dorado',
    tamano: 'grande',
    senas_particulares: 'pelaje claro',
  }, usuario.id_usuario);
  reporte = await crearReporteExtravio({
    id_mascota: mascota.id_mascota,
    fecha_perdida: new Date(Date.now() - 3600000).toISOString(),
    ubicacion: { latitud: 15.7835, longitud: -86.7918 },
    referencia_lugar: 'Prueba visual temporal',
    radio_km: 5,
  }, usuario.id_usuario);

  const buffer = await readFile(rutaImagen);
  foto = await agregarFotoMascota(
    mascota.id_mascota,
    usuario.id_usuario,
    { buffer },
    true
  );
  assert.equal(foto.procesamiento, 'vector_generado');
  assert.equal(await modelos.VectorVisual.count({
    where: { id_foto_mascota: foto.id_foto },
  }), 1);

  servidor = createServer(app);
  servidor.listen(0, '127.0.0.1');
  await once(servidor, 'listening');
  const formulario = new FormData();
  formulario.append('foto', new Blob([buffer], { type: 'image/jpeg' }), 'consulta.jpg');
  const respuesta = await fetch(
    `http://127.0.0.1:${servidor.address().port}/api/coincidencias/visuales/buscar`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens.access_token}` },
      body: formulario,
    }
  );
  const cuerpo = await respuesta.json();
  assert.equal(respuesta.status, 200, JSON.stringify(cuerpo));
  assert.equal(String(cuerpo.data.coincidencias[0].id_mascota), String(mascota.id_mascota));
  assert.ok(cuerpo.data.coincidencias[0].similitud > 0.999);
  assert.equal(cuerpo.data.coincidencias.length, 1);

  const formularioEscaneo = new FormData();
  formularioEscaneo.append('foto', new Blob([buffer], { type: 'image/jpeg' }), 'escaneo.jpg');
  formularioEscaneo.append('tipo_captura', 'lejos');
  formularioEscaneo.append('datos', JSON.stringify({
    fecha_avistamiento: new Date().toISOString(),
    ubicacion: { latitud: 15.7836, longitud: -86.7917 },
  }));
  const respuestaEscaneo = await fetch(
    `http://127.0.0.1:${servidor.address().port}/api/avistamientos/escanear/registrado`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens.access_token}` },
      body: formularioEscaneo,
    }
  );
  const cuerpoEscaneo = await respuestaEscaneo.json();
  assert.equal(respuestaEscaneo.status, 201, JSON.stringify(cuerpoEscaneo));
  avistamientoEscaneo = cuerpoEscaneo.data;
  fotoEscaneo = cuerpoEscaneo.data.foto;
  assert.equal(fotoEscaneo.vector_generado, true);
  assert.equal(cuerpoEscaneo.data.resultado.coincidencias.length, 1);
  assert.equal(
    String(cuerpoEscaneo.data.resultado.coincidencias[0].id_mascota),
    String(mascota.id_mascota)
  );
  const coincidencia = await modelos.Coincidencia.findOne({
    where: { id_avistamiento: avistamientoEscaneo.id_avistamiento },
  });
  assert.ok(coincidencia);
  assert.equal(coincidencia.metodo, 'mixto');
  assert.ok(Number(coincidencia.puntuacion_visual) > 0.999);
  assert.ok(Number(coincidencia.puntuacion_contexto) > 0);
  assert.ok(await modelos.Notificacion.findOne({
    where: { id_usuario: usuario.id_usuario, tipo: 'coincidencia_nueva' },
  }));

  console.log('Escaneo, coincidencia mixta y notificación de extremo a extremo: OK');
} finally {
  if (servidor?.listening) {
    await new Promise((resolve) => servidor.close(resolve));
  }
  if (reporte) await modelos.ReporteExtravio.destroy({ where: { id_reporte: reporte.id_reporte } });
  if (avistamientoEscaneo) {
    await modelos.Avistamiento.destroy({
      where: { id_avistamiento: avistamientoEscaneo.id_avistamiento },
    });
  }
  if (mascota) await modelos.FotoMascota.destroy({ where: { id_mascota: mascota.id_mascota } });
  if (mascota) await modelos.Mascota.destroy({ where: { id_mascota: mascota.id_mascota } });
  if (usuario) {
    await modelos.SesionUsuario.destroy({ where: { id_usuario: usuario.id_usuario } });
    await modelos.UsuarioRol.destroy({ where: { id_usuario: usuario.id_usuario } });
    await modelos.Usuario.destroy({ where: { id_usuario: usuario.id_usuario } });
  }
  if (foto) {
    await Promise.allSettled(
      [foto.url_original, foto.url_recorte]
        .filter(Boolean)
        .map((url) => unlink(path.resolve(process.cwd(), `.${url}`)))
    );
  }
  if (fotoEscaneo) {
    await Promise.allSettled(
      [fotoEscaneo.url_original, fotoEscaneo.url_recorte]
        .filter(Boolean)
        .map((url) => unlink(path.resolve(process.cwd(), `.${url}`)))
    );
  }
  await sequelize.close();
}
