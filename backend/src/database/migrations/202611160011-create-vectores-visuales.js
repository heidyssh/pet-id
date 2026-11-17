import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.createTable('vectores_visuales', {
    id_vector: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },
    id_foto_mascota: {
      type: DataTypes.BIGINT,
      allowNull: true,
      unique: true,
      references: { model: 'fotos_mascotas', key: 'id_foto' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    id_foto_avistamiento: {
      type: DataTypes.BIGINT,
      allowNull: true,
      unique: true,
      references: { model: 'fotos_avistamientos', key: 'id_foto' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    vector: {
      type: DataTypes.ARRAY(DataTypes.REAL),
      allowNull: false,
    },
    modelo: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    dimensiones: {
      type: DataTypes.SMALLINT,
      allowNull: false,
    },
    fecha_creacion: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  });

  await qi.sequelize.query(`
    ALTER TABLE vectores_visuales
    ADD CONSTRAINT vectores_visuales_una_fuente_check
    CHECK (
      (id_foto_mascota IS NOT NULL AND id_foto_avistamiento IS NULL) OR
      (id_foto_mascota IS NULL AND id_foto_avistamiento IS NOT NULL)
    )
  `);

  await qi.sequelize.query(`
    ALTER TABLE vectores_visuales
    ADD CONSTRAINT vectores_visuales_dimensiones_check
    CHECK (dimensiones = 384 AND cardinality(vector) = dimensiones)
  `);
}

export async function down({ context: qi }) {
  await qi.dropTable('vectores_visuales');
}
