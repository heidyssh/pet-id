import { z } from 'zod';

export const crearOrganizacionSchema = z.strictObject({
  nombre: z.string().trim().min(2).max(150),
  tipo: z.enum(['veterinaria', 'refugio']),
  direccion: z.string().trim().max(1000).nullable().optional(),
  telefono: z.string().trim().max(20).nullable().optional(),
  cargo: z.string().trim().min(2).max(80).default('administrador'),
});

export const actualizarOrganizacionSchema = z.strictObject({
  nombre: z.string().trim().min(2).max(150).optional(),
  direccion: z.string().trim().max(1000).nullable().optional(),
  telefono: z.string().trim().max(20).nullable().optional(),
}).refine((datos) => Object.keys(datos).length > 0, 'Debe enviar al menos un campo');

export const membresiaSchema = z.strictObject({
  id_usuario: z.union([z.number().int().positive().safe(), z.string().regex(/^[1-9]\d{0,18}$/)]).transform(String),
  cargo: z.string().trim().min(2).max(80).nullable().optional(),
  activo: z.boolean().default(true),
});

export const verificarOrganizacionSchema = z.strictObject({
  verificada: z.boolean(),
});
