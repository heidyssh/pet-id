import { z } from 'zod';

export const estadoUsuarioSchema = z.strictObject({ activo: z.boolean() });
export const rolesUsuarioSchema = z.strictObject({
  roles: z.array(z.enum(['ciudadano', 'personal_veterinario', 'personal_refugio', 'administrador'])).min(1),
});

export const estadoAvistamientoSchema = z.strictObject({
  estado: z.enum(['registrado', 'revisado', 'descartado']),
});
