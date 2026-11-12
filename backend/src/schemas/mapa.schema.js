import { z } from 'zod';

export const geocodificarSchema = z.strictObject({
  direccion: z.string().trim().min(3).max(300),
});

export const geocodificacionReversaSchema = z.strictObject({
  latitud: z.coerce.number().min(-90).max(90),
  longitud: z.coerce.number().min(-180).max(180),
});
