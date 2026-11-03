
export async function seedRazas(sequelize, transaction) {
  const razas = [
    // Perros
    { especie: 'Perro', nombre: 'Mestizo' },
    { especie: 'Perro', nombre: 'Raza desconocida' },
    { especie: 'Perro', nombre: 'Labrador Retriever' },
    { especie: 'Perro', nombre: 'Golden Retriever' },
    { especie: 'Perro', nombre: 'Pastor Alemán' },
    { especie: 'Perro', nombre: 'Chihuahua' },
    { especie: 'Perro', nombre: 'Bulldog Francés' },
    { especie: 'Perro', nombre: 'Poodle' },
    { especie: 'Perro', nombre: 'Husky Siberiano' },
    { especie: 'Perro', nombre: 'Rottweiler' },

    // Gatos
    { especie: 'Gato', nombre: 'Mestizo' },
    { especie: 'Gato', nombre: 'Raza desconocida' },
    { especie: 'Gato', nombre: 'Siamés' },
    { especie: 'Gato', nombre: 'Persa' },
    { especie: 'Gato', nombre: 'Maine Coon' },
    { especie: 'Gato', nombre: 'Bengalí' },
  ];

  for (const raza of razas) {
    await sequelize.query(
      `
      INSERT INTO razas (id_especie, nombre)
      SELECT id_especie, :nombre
      FROM especies
      WHERE nombre = :especie
      ON CONFLICT (id_especie, nombre) DO NOTHING
      `,
      {
        replacements: {
          especie: raza.especie,
          nombre: raza.nombre,
        },
        transaction,
      }
    );
  }
}
