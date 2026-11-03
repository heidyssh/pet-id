
export async function seedEspecies(sequelize, transaction) {
  const especies = [
    'Perro',
    'Gato',
  ];

  for (const nombre of especies) {
    await sequelize.query(
      `
      INSERT INTO especies (nombre)
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
