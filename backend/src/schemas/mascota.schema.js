
import { z } from 'zod';

const idRazaSchema = z.union([
  z.number().int().positive().safe(),
  z.string().regex(/^[1-9]\d{0,18}$/),
]).transform(String).nullable();

export const crearMascotaSchema = z.strictObject({
  nombre: z.string().trim().min(1).max(100),

  id_especie: z.number().int().positive().max(32767),

  id_raza: idRazaSchema.optional(),

  sexo: z.string().trim().max(15).nullable().optional(),

  color_principal: z.string().trim().min(1).max(50),

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

  fecha_nacimiento: z.iso.date().nullable().optional(),
});

export const actualizarMascotaSchema =
  crearMascotaSchema.partial().refine(
    (datos) => Object.keys(datos).length > 0,
    'Debe proporcionar al menos un campo'
  );

export const paginacionMascotasSchema = z.strictObject({
  pagina: z.coerce.number()
    .int()
    .min(1)
    .max(100000)
    .default(1),

  limite: z.coerce.number()
    .int()
    .min(1)
    .max(50)
    .default(10),
});
