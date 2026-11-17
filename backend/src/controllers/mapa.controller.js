import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { geocodificarSchema, geocodificacionReversaSchema } from '../schemas/mapa.schema.js';
import {
  geocodificarDireccion,
  geocodificacionReversa,
  configuracionPublicaMapa,
} from '../services/mapa.service.js';

function validar(schema, query) {
  const resultado = schema.safeParse(query);
  if (!resultado.success) throw new AppError('Parámetros de ubicación inválidos', 400);
  return resultado.data;
}

export const geocodificar = asyncHandler(async (req, res) => {
  const { direccion } = validar(geocodificarSchema, req.query);
  return res.json({ success: true, data: { items: await geocodificarDireccion(direccion) } });
});

export const reversa = asyncHandler(async (req, res) => {
  const { latitud, longitud } = validar(geocodificacionReversaSchema, req.query);
  return res.json({ success: true, data: { items: await geocodificacionReversa(latitud, longitud) } });
});

export const configuracion = asyncHandler(async (req, res) => {
  return res.json({
    success: true,
    data: configuracionPublicaMapa(),
  });
});
