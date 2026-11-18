
import { z } from 'zod';

const correoSchema = z.email()
  .trim()
  .toLowerCase()
  .max(150);

const passwordSchema = z.string()
  .min(8, 'La contraseña debe tener al menos 8 caracteres')
  .refine((valor) => valor.trim().length > 0, 'La contraseña es obligatoria')
  .refine(
    (valor) => Buffer.byteLength(valor, 'utf8') <= 72,
    'La contraseña es demasiado larga'
  );

const nombrePersonaSchema = z.string()
  .trim()
  .normalize()
  .regex(/^(?:\p{L}\p{M}*)+(?: (?:\p{L}\p{M}*)+)?$/u,
    'Usa solo letras y, si hace falta, un espacio entre palabras')
  .refine((valor) => (valor.match(/\p{L}/gu)?.length ?? 0) >= 2,
    'Escribe al menos dos letras')
  .refine((valor) => (valor.match(/\p{L}/gu)?.length ?? 0) <= 50,
    'Escribe un máximo de 50 letras')
  .refine((valor) => Array.from(valor).length <= 100,
    'El texto contiene demasiados signos combinados');

export const registroSchema = z.strictObject({
  nombre: nombrePersonaSchema,
  apellido: nombrePersonaSchema,
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
