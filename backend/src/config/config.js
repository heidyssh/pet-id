
import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z
    .enum(['development', 'test', 'production'])
    .default('development'),

  PORT: z.coerce.number().int().positive().default(3000),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL es requerida'),

  JWT_SECRET: z.string().min(32, 'JWT_SECRET debe tener al menos 32 caracteres'),

  FRONTEND_ORIGIN: z
    .string()
    .url()
    .default('http://localhost:5173'),

  DB_POOL_MAX: z.coerce.number().int().positive().default(5),
});

const resultado = envSchema.safeParse(process.env);

if (!resultado.success) {
  console.error('Error en las variables de entorno:');
  console.error(z.treeifyError(resultado.error));
  process.exit(1);
}

export const env = resultado.data;
