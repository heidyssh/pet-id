import { z } from 'zod';

export const geocodificarSchema = z.strictObject({
  direccion: z.string().trim().min(3).max(300),
  cerca_latitud: z.coerce.number().min(-90).max(90).optional(),
  cerca_longitud: z.coerce.number().min(-180).max(180).optional(),
}).refine(
  (datos) =>
    (datos.cerca_latitud === undefined) ===
    (datos.cerca_longitud === undefined),
  { message: 'La ubicación de referencia debe incluir latitud y longitud' }
);

export const geocodificacionReversaSchema = z.strictObject({
  latitud: z.coerce.number().min(-90).max(90),
  longitud: z.coerce.number().min(-180).max(180),
});
