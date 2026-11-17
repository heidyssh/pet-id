import { createHash, randomUUID } from 'node:crypto';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';

import { env } from '../config/config.js';
import { AppError } from '../utils/AppError.js';

const RAIZ_LOCAL = path.resolve(process.cwd(), 'storage', 'imagenes');

function firmaCloudinary(parametros) {
  const cadena = Object.entries(parametros)
    .filter(([, valor]) => valor !== undefined && valor !== null && valor !== '')
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([clave, valor]) => `${clave}=${valor}`)
    .join('&');

  return createHash('sha1')
    .update(`${cadena}${env.CLOUDINARY_API_SECRET}`)
    .digest('hex');
}

function comprobarCloudinary() {
  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new AppError('Cloudinary no esta configurado completamente', 503);
  }
}

async function subirCloudinary(buffer, prefijo) {
  comprobarCloudinary();
  const timestamp = Math.floor(Date.now() / 1000);
  const folder = env.CLOUDINARY_FOLDER;
  const publicId = `${prefijo}-${randomUUID()}`;
  const parametros = { folder, public_id: publicId, timestamp };
  const formulario = new FormData();

  formulario.append('file', new Blob([buffer], { type: 'image/webp' }), `${publicId}.webp`);
  formulario.append('api_key', env.CLOUDINARY_API_KEY);
  formulario.append('timestamp', String(timestamp));
  formulario.append('folder', folder);
  formulario.append('public_id', publicId);
  formulario.append('signature', firmaCloudinary(parametros));

  let respuesta;
  try {
    respuesta = await fetch(
      `https://api.cloudinary.com/v1_1/${encodeURIComponent(env.CLOUDINARY_CLOUD_NAME)}/image/upload`,
      { method: 'POST', body: formulario, signal: AbortSignal.timeout(30000) }
    );
  } catch (error) {
    throw new AppError(`No se pudo conectar con Cloudinary: ${error.message}`, 502);
  }

  const cuerpo = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok || !cuerpo.secure_url || !cuerpo.public_id) {
    throw new AppError(cuerpo.error?.message ?? 'Cloudinary rechazo la imagen', 502);
  }

  return {
    proveedor: 'cloudinary',
    id: cuerpo.public_id,
    url: cuerpo.secure_url,
  };
}

async function eliminarCloudinary(publicId) {
  comprobarCloudinary();
  const timestamp = Math.floor(Date.now() / 1000);
  const parametros = { public_id: publicId, timestamp };
  const formulario = new URLSearchParams({
    public_id: publicId,
    timestamp: String(timestamp),
    api_key: env.CLOUDINARY_API_KEY,
    signature: firmaCloudinary(parametros),
  });
  const respuesta = await fetch(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(env.CLOUDINARY_CLOUD_NAME)}/image/destroy`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: formulario,
      signal: AbortSignal.timeout(30000),
    }
  );
  const cuerpo = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok || !['ok', 'not found'].includes(cuerpo.result)) {
    throw new AppError(cuerpo.error?.message ?? 'No se pudo eliminar la imagen de Cloudinary', 502);
  }
}

async function guardarLocal(buffer, prefijo) {
  await mkdir(RAIZ_LOCAL, { recursive: true });
  const nombre = `${prefijo}-${randomUUID()}.webp`;
  await writeFile(path.join(RAIZ_LOCAL, nombre), buffer, { flag: 'wx' });
  return {
    proveedor: 'local',
    id: nombre,
    url: `/storage/imagenes/${nombre}`,
  };
}

export async function guardarImagen(buffer, prefijo) {
  return env.IMAGE_STORAGE_PROVIDER === 'cloudinary'
    ? subirCloudinary(buffer, prefijo)
    : guardarLocal(buffer, prefijo);
}

export async function eliminarImagen(imagen) {
  if (!imagen?.id) return;
  if (imagen.proveedor === 'cloudinary') {
    await eliminarCloudinary(imagen.id);
    return;
  }
  await unlink(path.join(RAIZ_LOCAL, path.basename(imagen.id)));
}

