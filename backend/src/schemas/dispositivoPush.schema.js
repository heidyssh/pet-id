import { z } from 'zod';

export const registrarDispositivoPushSchema = z.strictObject({
  token: z.string().trim().min(20).max(4096),
  plataforma: z.enum(['android', 'ios', 'web']),
});

export const eliminarDispositivoPushSchema = z.strictObject({
  token: z.string().trim().min(20).max(4096),
});
