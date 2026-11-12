import { env } from '../config/config.js';
import { AppError } from '../utils/AppError.js';

const ETIQUETAS_ANIMAL = new Set([
  'animal',
  'cat',
  'dog',
  'mammal',
  'pet',
]);

function cajaGoogle(anotacion) {
  const vertices = anotacion.boundingPoly?.normalizedVertices;

  if (!Array.isArray(vertices) || vertices.length < 4) {
    return null;
  }

  const xs = vertices.map((vertice) => vertice.x ?? 0);
  const ys = vertices.map((vertice) => vertice.y ?? 0);

  return {
    x_min: Math.max(0, Math.min(...xs)),
    y_min: Math.max(0, Math.min(...ys)),
    x_max: Math.min(1, Math.max(...xs)),
    y_max: Math.min(1, Math.max(...ys)),
  };
}

async function detectarConGoogle(buffer) {
  if (!env.GOOGLE_VISION_API_KEY) {
    throw new AppError(
      'Google Vision no tiene credenciales configuradas',
      503
    );
  }

  const respuesta = await fetch(
    `https://vision.googleapis.com/v1/images:annotate?key=${encodeURIComponent(env.GOOGLE_VISION_API_KEY)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requests: [{
          image: { content: buffer.toString('base64') },
          features: [{ type: 'OBJECT_LOCALIZATION', maxResults: 10 }],
        }],
      }),
      signal: AbortSignal.timeout(15000),
    }
  );

  if (!respuesta.ok) {
    throw new AppError('El proveedor visual no pudo procesar la imagen', 502);
  }

  const cuerpo = await respuesta.json();
  const resultado = cuerpo.responses?.[0];

  if (resultado?.error) {
    throw new AppError('El proveedor visual rechazó la imagen', 502);
  }

  const candidatos = (resultado?.localizedObjectAnnotations ?? [])
    .filter((item) => ETIQUETAS_ANIMAL.has(item.name?.toLowerCase()))
    .map((item) => ({
      etiqueta: item.name,
      confianza: item.score,
      caja: cajaGoogle(item),
    }))
    .filter((item) => item.caja)
    .sort((a, b) => b.confianza - a.confianza);

  return candidatos[0] ?? null;
}

export function proveedorVisualConfigurado() {
  return env.VISION_PROVIDER !== 'disabled';
}

export async function detectarAnimal(buffer) {
  if (env.VISION_PROVIDER === 'disabled') {
    return null;
  }

  if (env.VISION_PROVIDER === 'google') {
    return detectarConGoogle(buffer);
  }

  throw new AppError('Proveedor visual no soportado', 500);
}
