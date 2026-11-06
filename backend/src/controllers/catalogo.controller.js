
import {
  listarEspecies,
  listarRazas,
} from '../services/catalogo.service.js';

import { razasQuerySchema } from '../schemas/catalogo.schema.js';
import { AppError } from '../utils/AppError.js';
import { asyncHandler } from '../utils/asyncHandler.js';

export const obtenerEspecies = asyncHandler(
  async (req, res) => {
    const especies = await listarEspecies();

    return res.status(200).json({
      success: true,
      data: especies,
    });
  }
);

export const obtenerRazas = asyncHandler(
  async (req, res) => {
    const resultado = razasQuerySchema.safeParse(
      req.query
    );

    if (!resultado.success) {
      throw new AppError(
        'Filtros de razas inválidos',
        400
      );
    }

    const razas = await listarRazas(
      resultado.data.id_especie
    );

    return res.status(200).json({
      success: true,
      data: razas,
    });
  }
);
