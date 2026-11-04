
import { z } from 'zod';

const correoSchema = z.email()
  .trim()
  .toLowerCase()
  .max(150);

const passwordSchema = z.string()
  .min(12, 'La contraseña debe tener al menos 12 caracteres')
  .refine(
    (valor) => Buffer.byteLength(valor, 'utf8') <= 72,
    'La contraseña es demasiado larga'
  );

export const registroSchema = z.strictObject({
  nombre: z.string().trim().min(2).max(100),
  apellido: z.string().trim().min(2).max(100),
  correo: correoSchema,
  password: passwordSchema,
  telefono: z.string().trim().min(1).max(20).optional(),
  dni: z.string().trim().min(1).max(20).optional(),
});

export const loginSchema = z.strictObject({
  correo: correoSchema,
  password: z.string().min(1).max(1024),
});

export const solicitudCorreoSchema = z.strictObject({
  correo: z.email().trim().toLowerCase().max(150),
});

export const confirmarTokenSchema = z.strictObject({
  token: z.string().regex(/^[a-f0-9]{64}$/),
});

export const restablecerPasswordSchema = z.strictObject({
  token: z.string().regex(/^[a-f0-9]{64}$/),
  password: z.string()
    .min(12)
    .refine(
      (valor) => Buffer.byteLength(valor, 'utf8') <= 72,
      'Contraseña demasiado larga'
    ),
});
