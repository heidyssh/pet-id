
import { z } from 'zod';

const ubicacionSchema = z.strictObject({
  latitud: z.number().min(-90).max(90),
  longitud: z.number().min(-180).max(180),
});

export const crearAvistamientoSchema = z.strictObject({
  id_especie: z.number()
    .int()
    .positive()
    .max(32767)
    .nullable()
    .optional(),

  fecha_avistamiento: z.iso.datetime({
    offset: true,
  }).refine(
    (fecha) => new Date(fecha).getTime() <= Date.now(),
    'La fecha no puede estar en el futuro'
  ),

  ubicacion: ubicacionSchema.nullable().optional(),

  referencia_lugar: z.string()
    .trim()
    .min(1)
    .max(500)
    .nullable()
    .optional(),

  color_principal: z.string()
    .trim()
    .max(50)
    .nullable()
    .optional(),

  tamano: z.enum([
    'pequeno',
    'mediano',
    'grande',
  ]).nullable().optional(),

  senas_particulares: z.string()
    .trim()
    .max(2000)
    .nullable()
    .optional(),

  descripcion: z.string()
    .trim()
    .min(1)
    .max(3000),
}).refine(
  (datos) =>
    datos.ubicacion != null ||
    Boolean(datos.referencia_lugar),
  {
    message: 'Indicá una ubicación o referencia del lugar',
  }
);

export const listarAvistamientosSchema = z.strictObject({
  pagina: z.coerce.number().int().min(1).default(1),
  limite: z.coerce.number().int().min(1).max(50).default(10),

  id_especie: z.coerce.number()
    .int()
    .positive()
    .max(32767)
    .optional(),
});
