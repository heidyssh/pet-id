import { createSign } from 'node:crypto';

import { env } from '../config/config.js';
import { DispositivoPush } from '../models/index.js';

let tokenAcceso = null;
let tokenExpiraEn = 0;

function base64url(valor) {
  return Buffer.from(valor).toString('base64url');
}

export function pushConfigurado() {
  return Boolean(env.FCM_PROJECT_ID && env.FCM_CLIENT_EMAIL && env.FCM_PRIVATE_KEY);
}

async function obtenerTokenAcceso() {
  if (tokenAcceso && Date.now() < tokenExpiraEn) return tokenAcceso;
  const ahora = Math.floor(Date.now() / 1000);
  const encabezado = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const carga = base64url(JSON.stringify({
    iss: env.FCM_CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: ahora,
    exp: ahora + 3600,
  }));
  const firmador = createSign('RSA-SHA256');
  firmador.update(`${encabezado}.${carga}`);
  firmador.end();
  const llave = env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n');
  const assertion = `${encabezado}.${carga}.${firmador.sign(llave, 'base64url')}`;

  const respuesta = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
    signal: AbortSignal.timeout(15000),
  });
  if (!respuesta.ok) throw new Error('No se pudo autenticar Firebase Cloud Messaging');
  const cuerpo = await respuesta.json();
  tokenAcceso = cuerpo.access_token;
  tokenExpiraEn = Date.now() + (Number(cuerpo.expires_in ?? 3600) - 60) * 1000;
  return tokenAcceso;
}

function datosTexto(datos) {
  return Object.fromEntries(
    Object.entries(datos ?? {}).map(([clave, valor]) => [
      clave,
      typeof valor === 'string' ? valor : JSON.stringify(valor),
    ])
  );
}

export async function enviarPushUsuario(idUsuario, notificacion) {
  if (!pushConfigurado()) return 0;
  const dispositivos = await DispositivoPush.findAll({
    where: { id_usuario: idUsuario, activo: true },
  });
  if (!dispositivos.length) return 0;
  const acceso = await obtenerTokenAcceso();
  let enviadas = 0;

  for (const dispositivo of dispositivos) {
    const respuesta = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FCM_PROJECT_ID)}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${acceso}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: dispositivo.token,
            notification: {
              title: notificacion.titulo,
              body: notificacion.mensaje,
            },
            data: datosTexto(notificacion.datos),
          },
        }),
        signal: AbortSignal.timeout(15000),
      }
    );
    if (respuesta.ok) {
      enviadas += 1;
    } else {
      const error = await respuesta.text();
      if (respuesta.status === 404 || error.includes('UNREGISTERED')) {
        await dispositivo.update({ activo: false, fecha_actualizacion: new Date() });
      }
    }
  }
  return enviadas;
}

export async function registrarDispositivoPush(idUsuario, datos) {
  const [dispositivo] = await DispositivoPush.upsert({
    id_usuario: idUsuario,
    token: datos.token,
    plataforma: datos.plataforma,
    activo: true,
    fecha_actualizacion: new Date(),
  }, { returning: true });
  return {
    id_dispositivo: dispositivo.id_dispositivo,
    plataforma: dispositivo.plataforma,
    activo: dispositivo.activo,
  };
}

export async function eliminarDispositivoPush(idUsuario, token) {
  await DispositivoPush.destroy({ where: { id_usuario: idUsuario, token } });
}
