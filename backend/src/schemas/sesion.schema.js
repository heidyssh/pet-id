
import { z } from 'zod';

export const renovarSesionSchema = z.strictObject({
  refresh_token: z.string()
    .regex(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.[a-f0-9]{64}$/i,
      'Token de renovación inválido'
    ),
});

export const idSesionSchema = z.strictObject({
  idSesion: z.uuid(),
});
