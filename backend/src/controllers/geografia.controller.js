import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { cercanosSchema } from '../schemas/geografia.schema.js';
import {
  extraviosCercanos,
  avistamientosCercanos,
} from '../services/geografia.service.js';

function filtros(query) {
  const resultado = cercanosSchema.safeParse(query);
  if (!resultado.success) {
    throw new AppError('Parámetros geográficos inválidos', 400);
  }
  return resultado.data;
}

export const buscarExtraviosCercanos = asyncHandler(async (req, res) => {
  const data = await extraviosCercanos(filtros(req.query));
  return res.status(200).json({ success: true, data });
});

export const buscarAvistamientosCercanos = asyncHandler(async (req, res) => {
  const data = await avistamientosCercanos(filtros(req.query));
  return res.status(200).json({ success: true, data });
});
