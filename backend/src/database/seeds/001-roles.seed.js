
export async function seedRoles(sequelize, transaction) {
  const roles = [
    'ciudadano',
    'personal_veterinario',
    'personal_refugio',
    'administrador',
  ];

  for (const nombre of roles) {
    await sequelize.query(
      `
      INSERT INTO roles (nombre)
      VALUES (:nombre)
      ON CONFLICT (nombre) DO NOTHING
      `,
      {
        replacements: { nombre },
        transaction,
      }
    );
  }
}
