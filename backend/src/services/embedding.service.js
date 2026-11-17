import { pipeline, RawImage } from '@huggingface/transformers';

import { env } from '../config/config.js';
import { AppError } from '../utils/AppError.js';

export const DIMENSIONES_VECTOR = 384;

let promesaExtractor;

function obtenerExtractor() {
  if (!promesaExtractor) {
    promesaExtractor = pipeline(
      'image-feature-extraction',
      env.DINO_MODEL_ID,
      { dtype: 'q8' }
    ).catch((error) => {
      promesaExtractor = undefined;
      throw error;
    });
  }
  return promesaExtractor;
}

function normalizar(vector) {
  const norma = Math.sqrt(vector.reduce((suma, valor) => suma + valor * valor, 0));
  if (!Number.isFinite(norma) || norma === 0) {
    throw new AppError('DINOv2 produjo un vector visual inválido', 502);
  }
  return vector.map((valor) => valor / norma);
}

function extraerTokenClase(tensor) {
  const datos = Array.from(tensor?.data ?? []);
  const dimensiones = tensor?.dims ?? [];

  if (dimensiones.length === 2 && dimensiones.at(-1) === DIMENSIONES_VECTOR) {
    return datos.slice(0, DIMENSIONES_VECTOR);
  }
  if (dimensiones.length === 3 && dimensiones.at(-1) === DIMENSIONES_VECTOR) {
    return datos.slice(0, DIMENSIONES_VECTOR);
  }
  throw new AppError('El modelo DINOv2 devolvió dimensiones inesperadas', 502);
}

export async function generarVectorVisual(buffer) {
  try {
    const imagen = await RawImage.fromBlob(new Blob([buffer], { type: 'image/webp' }));
    const extractor = await obtenerExtractor();
    const salida = await extractor(imagen);
    return normalizar(extraerTokenClase(salida));
  } catch (error) {
    if (error instanceof AppError) throw error;
    throw new AppError('No se pudo generar el vector visual con DINOv2', 502);
  }
}

export function similitudCoseno(vectorA, vectorB) {
  if (
    !Array.isArray(vectorA) || !Array.isArray(vectorB) ||
    vectorA.length !== vectorB.length || vectorA.length === 0
  ) return null;

  let producto = 0;
  let normaA = 0;
  let normaB = 0;
  for (let i = 0; i < vectorA.length; i += 1) {
    producto += vectorA[i] * vectorB[i];
    normaA += vectorA[i] * vectorA[i];
    normaB += vectorB[i] * vectorB[i];
  }
  if (normaA === 0 || normaB === 0) return null;
  return producto / Math.sqrt(normaA * normaB);
}
