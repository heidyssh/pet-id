export const ROLES = Object.freeze({
  CIUDADANO: 'ciudadano',
  PERSONAL_VETERINARIO: 'personal_veterinario',
  PERSONAL_REFUGIO: 'personal_refugio',
  ADMINISTRADOR: 'administrador',
});

export const ROLES_PERSONAL = Object.freeze([
  ROLES.PERSONAL_VETERINARIO,
  ROLES.PERSONAL_REFUGIO,
]);
