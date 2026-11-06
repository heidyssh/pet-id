
import { z } from 'zod';

export const razasQuerySchema = z.strictObject({
  id_especie: z.coerce.number()
    .int()
    .positive()
    .max(32767)
    .optional(),
});
