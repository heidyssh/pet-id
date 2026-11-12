import { env } from '../config/config.js';
import { AppError } from '../utils/AppError.js';

function claveServidor() {
  if (!env.GOOGLE_MAPS_SERVER_API_KEY) {
    throw new AppError('Google Maps no tiene credenciales configuradas', 503);
  }
  return env.GOOGLE_MAPS_SERVER_API_KEY;
}

function limpiarResultado(item) {
  return {
    direccion: item.formatted_address,
    place_id: item.place_id,
    tipos: item.types,
    ubicacion: {
      latitud: item.geometry.location.lat,
      longitud: item.geometry.location.lng,
    },
    viewport: item.geometry.viewport ?? null,
  };
}

async function consultar(parametros) {
  const query = new URLSearchParams({
    ...parametros,
    key: claveServidor(),
    language: 'es',
    region: 'hn',
  });
  const respuesta = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?${query}`,
    { signal: AbortSignal.timeout(10000) }
  );
  if (!respuesta.ok) {
    throw new AppError('Google Maps no respondió correctamente', 502);
  }
  const cuerpo = await respuesta.json();
  if (cuerpo.status === 'ZERO_RESULTS') return [];
  if (cuerpo.status !== 'OK') {
    throw new AppError('Google Maps rechazó la consulta', 502);
  }
  return cuerpo.results.slice(0, 8).map(limpiarResultado);
}

export function geocodificarDireccion(direccion) {
  return consultar({ address: direccion, components: 'country:HN' });
}

export function geocodificacionReversa(latitud, longitud) {
  return consultar({ latlng: `${latitud},${longitud}`, result_type: 'street_address|route|locality' });
}
