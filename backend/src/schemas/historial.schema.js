import { z } from 'zod';

export const crearHistorialSchema = z.strictObject({
  tipo_registro: z.enum(['vacuna', 'desparasitacion', 'consulta', 'tratamiento']),
  descripcion: z.string().trim().min(2).max(5000),
  fecha_aplicacion: z.iso.date(),
  proxima_fecha: z.iso.date().nullable().optional(),
});

export const crearHistorialPropioSchema = crearHistorialSchema.extend({
  tipo_registro: z.enum(['vacuna', 'desparasitacion']),
});

export const actualizarHistorialSchema = crearHistorialSchema.partial()
  .refine((datos) => Object.keys(datos).length > 0, 'Debe enviar al menos un campo');
