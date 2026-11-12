import { z } from 'zod';

export const revisarCoincidenciaSchema = z.strictObject({
  estado_revision: z.enum(['confirmada', 'descartada']),
});
