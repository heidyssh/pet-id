import { mkdir, writeFile, unlink } from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';

import { sequelize } from '../config/sequelize.js';
import {
  Mascota,
  Avistamiento,
  FotoMascota,
  FotoAvistamiento,
} from '../models/index.js';
import { AppError } from '../utils/AppError.js';
import {
  detectarAnimal,
  proveedorVisualConfigurado,
} from './vision.service.js';

const RAIZ = path.resolve(process.cwd(), 'storage', 'imagenes');

async function guardar(buffer, prefijo) {
  await mkdir(RAIZ, { recursive: true });
  const nombre = `${prefijo}-${randomUUID()}.webp`;
  await writeFile(path.join(RAIZ, nombre), buffer, { flag: 'wx' });
  return { nombre, url: `/storage/imagenes/${nombre}` };
}

function region(caja, ancho, alto) {
  const margen = 0.08;
  const izquierda = Math.max(0, caja.x_min - margen);
  const arriba = Math.max(0, caja.y_min - margen);
  const derecha = Math.min(1, caja.x_max + margen);
  const abajo = Math.min(1, caja.y_max + margen);

  return {
    left: Math.floor(izquierda * ancho),
    top: Math.floor(arriba * alto),
    width: Math.max(1, Math.ceil((derecha - izquierda) * ancho)),
    height: Math.max(1, Math.ceil((abajo - arriba) * alto)),
  };
}

async function procesar(buffer) {
  let normalizada;

  try {
    normalizada = await sharp(buffer, { failOn: 'error' })
      .rotate()
      .resize({ width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 85 })
      .toBuffer();
  } catch {
    throw new AppError('La imagen no es válida o está dañada', 400);
  }

  const deteccion = await detectarAnimal(normalizada);
  let recorte = null;

  if (deteccion) {
    const metadata = await sharp(normalizada).metadata();
    recorte = await sharp(normalizada)
      .extract(region(deteccion.caja, metadata.width, metadata.height))
      .resize({ width: 1024, height: 1024, fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 88 })
      .toBuffer();
  }

  return { normalizada, recorte, deteccion };
}

export async function agregarFotoMascota(idMascota, idUsuario, archivo, esPrincipal) {
  if (!archivo) throw new AppError('Debe enviar una fotografía', 400);

  const mascota = await Mascota.findOne({
    where: { id_mascota: idMascota, id_dueno: idUsuario },
  });
  if (!mascota) throw new AppError('Mascota no encontrada', 404);

  const { normalizada, recorte, deteccion } = await procesar(archivo.buffer);
  const original = await guardar(normalizada, 'mascota');
  let recortada;

  try {
    if (recorte) recortada = await guardar(recorte, 'mascota-crop');

    return await sequelize.transaction(async (transaction) => {
      const cantidad = await FotoMascota.count({
        where: { id_mascota: idMascota },
        transaction,
      });
      const principal = esPrincipal === true || cantidad === 0;
      if (principal) {
        await FotoMascota.update(
          { es_principal: false },
          { where: { id_mascota: idMascota }, transaction }
        );
      }
      const foto = await FotoMascota.create({
        id_mascota: idMascota,
        url_original: original.url,
        url_recorte: recortada?.url ?? null,
        es_principal: principal,
      }, { transaction });
      return {
        ...foto.toJSON(),
        procesamiento: proveedorVisualConfigurado()
          ? deteccion ? 'animal_detectado' : 'animal_no_detectado'
          : 'proveedor_no_configurado',
      };
    });
  } catch (error) {
    await Promise.allSettled([
      unlink(path.join(RAIZ, original.nombre)),
      recortada && unlink(path.join(RAIZ, recortada.nombre)),
    ].filter(Boolean));
    throw error;
  }
}

export async function agregarFotoAvistamiento(idAvistamiento, idUsuario, archivo, tipoCaptura) {
  if (!archivo) throw new AppError('Debe enviar una fotografía', 400);
  if (!['cerca', 'lejos', 'desconocida'].includes(tipoCaptura ?? 'desconocida')) {
    throw new AppError('Tipo de captura inválido', 400);
  }

  const avistamiento = await Avistamiento.findOne({
    where: { id_avistamiento: idAvistamiento, id_usuario: idUsuario },
  });
  if (!avistamiento) throw new AppError('Avistamiento no encontrado', 404);

  const { normalizada, recorte, deteccion } = await procesar(archivo.buffer);
  const original = await guardar(normalizada, 'avistamiento');
  const recortada = recorte ? await guardar(recorte, 'avistamiento-crop') : null;
  const configurado = proveedorVisualConfigurado();

  return FotoAvistamiento.create({
    id_avistamiento: idAvistamiento,
    url_original: original.url,
    url_recorte: recortada?.url ?? null,
    tipo_captura: tipoCaptura ?? 'desconocida',
    estado_procesamiento: configurado
      ? deteccion ? 'procesada' : 'fallida'
      : 'pendiente',
  });
}
