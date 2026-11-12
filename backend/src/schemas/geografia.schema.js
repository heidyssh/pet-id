import { z } from 'zod';

export const cercanosSchema = z.strictObject({
  latitud: z.coerce.number().min(-90).max(90),
  longitud: z.coerce.number().min(-180).max(180),
  radio_km: z.coerce.number().positive().max(100).default(10),
  id_especie: z.coerce.number().int().positive().max(32767).optional(),
  pagina: z.coerce.number().int().min(1).default(1),
  limite: z.coerce.number().int().min(1).max(100).default(25),
});
