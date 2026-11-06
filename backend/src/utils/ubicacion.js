
export function crearPuntoGeografico(ubicacion) {
  if (!ubicacion) {
    return null;
  }

  return {
    type: 'Point',
    coordinates: [
      ubicacion.longitud,
      ubicacion.latitud,
    ],
  };
}

export function validarIdPositivo(id) {
  return (
    typeof id === 'string' &&
    /^[1-9]\d{0,18}$/.test(id) &&
    BigInt(id) <= 9223372036854775807n
  );
}
