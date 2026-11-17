import { env } from '../config/config.js';
import { AppError } from '../utils/AppError.js';

function claveGeoapify() {
  if (!env.GEOAPIFY_API_KEY) {
    throw new AppError('Geoapify no tiene credenciales configuradas', 503);
  }
  return env.GEOAPIFY_API_KEY;
}

function limpiarResultado(feature) {
  const item = feature.properties;
  return {
    direccion: item.formatted,
    place_id: item.place_id,
    tipo: item.result_type,
    ubicacion: {
      latitud: item.lat,
      longitud: item.lon,
    },
    bbox: feature.bbox ?? null,
  };
}

async function consultar(ruta, parametros) {
  const query = new URLSearchParams({
    ...parametros,
    apiKey: claveGeoapify(),
    lang: 'es',
    limit: '8',
  });
  const respuesta = await fetch(
    `https://api.geoapify.com/v1/geocode/${ruta}?${query}`,
    { signal: AbortSignal.timeout(10000) }
  );
  if (!respuesta.ok) {
    throw new AppError('Geoapify no respondió correctamente', 502);
  }
  const cuerpo = await respuesta.json();
  return (cuerpo.features ?? []).slice(0, 8).map(limpiarResultado);
}

export function geocodificarDireccion(direccion) {
  return consultar('search', {
    text: direccion,
    filter: 'countrycode:hn',
  });
}

export function geocodificacionReversa(latitud, longitud) {
  return consultar('reverse', {
    lat: String(latitud),
    lon: String(longitud),
    countrycodes: 'hn',
  });
}

export function configuracionPublicaMapa() {
  return {
    motor: 'maplibre',
    proveedor_tiles: 'openfreemap',
    style_url: env.MAP_STYLE_URL,
    centro_inicial: {
      latitud: 15.7835,
      longitud: -86.7918,
      zoom: 12,
    },
    atribucion: '© OpenStreetMap contributors',
  };
}
