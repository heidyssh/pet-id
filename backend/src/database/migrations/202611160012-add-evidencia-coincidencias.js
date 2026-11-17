import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.addColumn('coincidencias', 'puntuacion_visual', {
    type: DataTypes.DECIMAL(5, 4),
    allowNull: true,
  });
  await qi.addColumn('coincidencias', 'puntuacion_contexto', {
    type: DataTypes.DECIMAL(5, 4),
    allowNull: true,
  });
  await qi.addColumn('coincidencias', 'detalles', {
    type: DataTypes.JSONB,
    allowNull: true,
  });
  await qi.sequelize.query(`
    ALTER TABLE coincidencias
    ADD CONSTRAINT coincidencias_evidencia_valida
    CHECK (
      (puntuacion_visual IS NULL OR puntuacion_visual BETWEEN 0 AND 1) AND
      (puntuacion_contexto IS NULL OR puntuacion_contexto BETWEEN 0 AND 1)
    )
  `);
}

export async function down({ context: qi }) {
  await qi.sequelize.query(`
    ALTER TABLE coincidencias
    DROP CONSTRAINT IF EXISTS coincidencias_evidencia_valida
  `);
  await qi.removeColumn('coincidencias', 'detalles');
  await qi.removeColumn('coincidencias', 'puntuacion_contexto');
  await qi.removeColumn('coincidencias', 'puntuacion_visual');
}
