
import 'dotenv/config';
import { z } from 'zod';

const correoOpcional = z.preprocess(
  (valor) => typeof valor === 'string' && valor.trim() === '' ? undefined : valor,
  z.string().email().optional()
);

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

  DEV_EMAIL_MODE: z
    .enum(['log', 'smtp'])
    .default('log'),

  VISION_PROVIDER: z
    .enum(['disabled', 'google', 'roboflow'])
    .default('disabled'),

  GOOGLE_VISION_API_KEY: z.string().optional(),

  ROBOFLOW_API_KEY: z.string().optional(),

  ROBOFLOW_MODEL_ID: z.string().optional(),

  ROBOFLOW_API_URL: z
    .string()
    .url()
    .default('https://serverless.roboflow.com'),

  DINO_MODEL_ID: z
    .string()
    .min(1)
    .default('onnx-community/dinov2-small'),

  VISUAL_MATCH_MIN_SCORE: z.coerce.number()
    .min(0)
    .max(1)
    .default(0.70),

  VISUAL_MATCH_LIMIT: z.coerce.number()
    .int()
    .min(1)
    .max(10)
    .default(5),

  GEOAPIFY_API_KEY: z.string().optional(),

  MAP_STYLE_URL: z
    .string()
    .url()
    .default('https://tiles.openfreemap.org/styles/liberty'),

  IMAGE_STORAGE_PROVIDER: z
    .enum(['local', 'cloudinary'])
    .default('local'),
  CLOUDINARY_CLOUD_NAME: z.string().optional(),
  CLOUDINARY_API_KEY: z.string().optional(),
  CLOUDINARY_API_SECRET: z.string().optional(),
  CLOUDINARY_FOLDER: z.string().min(1).default('petid'),

  FCM_PROJECT_ID: z.string().optional(),
  FCM_CLIENT_EMAIL: correoOpcional,
  FCM_PRIVATE_KEY: z.string().optional(),
}).superRefine((datos, contexto) => {
  if (datos.IMAGE_STORAGE_PROVIDER !== 'cloudinary') return;

  for (const campo of [
    'CLOUDINARY_CLOUD_NAME',
    'CLOUDINARY_API_KEY',
    'CLOUDINARY_API_SECRET',
  ]) {
    if (!datos[campo]?.trim()) {
      contexto.addIssue({
        code: 'custom',
        path: [campo],
        message: `${campo} es requerida cuando IMAGE_STORAGE_PROVIDER=cloudinary`,
      });
    }
  }
});

const resultado = envSchema.safeParse(process.env);

if (!resultado.success) {
  console.error('Error en las variables de entorno:');
  console.error(z.treeifyError(resultado.error));
  process.exit(1);
}

export const env = resultado.data;
