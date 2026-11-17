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

function cajaRoboflow(prediccion, ancho, alto) {
  if (
    !Number.isFinite(prediccion.x) ||
    !Number.isFinite(prediccion.y) ||
    !Number.isFinite(prediccion.width) ||
    !Number.isFinite(prediccion.height) ||
    !Number.isFinite(ancho) ||
    !Number.isFinite(alto) ||
    ancho <= 0 || alto <= 0
  ) {
    return null;
  }

  return {
    x_min: Math.max(0, (prediccion.x - prediccion.width / 2) / ancho),
    y_min: Math.max(0, (prediccion.y - prediccion.height / 2) / alto),
    x_max: Math.min(1, (prediccion.x + prediccion.width / 2) / ancho),
    y_max: Math.min(1, (prediccion.y + prediccion.height / 2) / alto),
  };
}

async function detectarConRoboflow(buffer) {
  if (!env.ROBOFLOW_API_KEY || !env.ROBOFLOW_MODEL_ID) {
    throw new AppError('Roboflow no tiene credenciales o modelo configurado', 503);
  }

  const respuesta = await fetch(
    `${env.ROBOFLOW_API_URL.replace(/\/$/, '')}/${env.ROBOFLOW_MODEL_ID}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Bearer ${env.ROBOFLOW_API_KEY}`,
      },
      body: buffer.toString('base64'),
      signal: AbortSignal.timeout(20000),
    }
  );

  if (!respuesta.ok) {
    throw new AppError('El proveedor visual no pudo procesar la imagen', 502);
  }

  const cuerpo = await respuesta.json();
  const resultado = Array.isArray(cuerpo) ? cuerpo[0] : cuerpo;
  const ancho = Number(resultado?.image?.width);
  const alto = Number(resultado?.image?.height);
  const candidatos = (resultado?.predictions ?? [])
    .filter((item) => ETIQUETAS_ANIMAL.has(
      String(item.class ?? item.class_name ?? '').toLowerCase()
    ))
    .map((item) => ({
      etiqueta: item.class ?? item.class_name,
      confianza: Number(item.confidence ?? 0),
      caja: cajaRoboflow(item, ancho, alto),
    }))
    .filter((item) => item.caja)
    .sort((a, b) => b.confianza - a.confianza);

  return candidatos[0] ?? null;
}

export function proveedorVisualConfigurado() {
  if (env.VISION_PROVIDER === 'google') {
    return Boolean(env.GOOGLE_VISION_API_KEY);
  }
  if (env.VISION_PROVIDER === 'roboflow') {
    return Boolean(env.ROBOFLOW_API_KEY && env.ROBOFLOW_MODEL_ID);
  }
  return false;
}

export async function detectarAnimal(buffer) {
  if (!proveedorVisualConfigurado()) {
    return null;
  }

  if (env.VISION_PROVIDER === 'google') {
    return detectarConGoogle(buffer);
  }

  if (env.VISION_PROVIDER === 'roboflow') {
    return detectarConRoboflow(buffer);
  }

  throw new AppError('Proveedor visual no soportado', 500);
}
