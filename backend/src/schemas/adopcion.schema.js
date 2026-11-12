import { z } from 'zod';

const id = z.union([z.number().int().positive().safe(), z.string().regex(/^[1-9]\d{0,18}$/)]).transform(String);

export const crearPublicacionSchema = z.strictObject({
  id_mascota: id,
  id_organizacion: id.nullable().optional(),
  descripcion: z.string().trim().min(10).max(5000),
});

export const crearSolicitudSchema = z.strictObject({
  mensaje: z.string().trim().max(3000).nullable().optional(),
});

export const revisarSolicitudSchema = z.strictObject({
  estado: z.enum(['aprobada', 'rechazada']),
});

export const cerrarPublicacionSchema = z.strictObject({
  estado: z.enum(['cerrada', 'cancelada']),
});
