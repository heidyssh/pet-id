
import { z } from 'zod';

const MARGEN_RELOJ_MS = 5 * 60 * 1000;

const idSchema = z.union([
  z.number().int().positive().safe(),
  z.string().regex(/^[1-9]\d{0,18}$/),
]).transform(String).refine(
  (id) => BigInt(id) <= 9223372036854775807n,
  'Identificador fuera de rango'
);

export const ubicacionSchema = z.strictObject({
  latitud: z.number().min(-90).max(90),
  longitud: z.number().min(-180).max(180),
});

export const crearExtravioSchema = z.strictObject({
  id_mascota: idSchema,

  fecha_perdida: z.iso.datetime({
    offset: true,
  }).refine(
    (fecha) =>
      new Date(fecha).getTime() <= Date.now() + MARGEN_RELOJ_MS,
    'La fecha no puede estar en el futuro'
  ),

  ubicacion: ubicacionSchema.nullable().optional(),

  referencia_lugar: z.string()
    .trim()
    .min(1)
    .max(500)
    .nullable()
    .optional(),

  radio_km: z.number()
    .positive()
    .max(100)
    .default(5),
}).refine(
  (datos) =>
    datos.ubicacion != null ||
    Boolean(datos.referencia_lugar),
  {
    message: 'Indicá una ubicación o referencia del lugar',
  }
);

export const listarExtraviosSchema = z.strictObject({
  pagina: z.coerce.number().int().min(1).default(1),
  limite: z.coerce.number().int().min(1).max(50).default(10),
});
