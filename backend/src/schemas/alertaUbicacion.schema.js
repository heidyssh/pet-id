import { z } from 'zod';

export const actualizarAlertaUbicacionSchema = z.strictObject({
  ubicacion: z.strictObject({
    latitud: z.number().min(-90).max(90),
    longitud: z.number().min(-180).max(180),
  }),
  radio_km: z.number().positive().max(50).default(10),
});
