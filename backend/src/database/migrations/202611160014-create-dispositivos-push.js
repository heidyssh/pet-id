import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.createTable('dispositivos_push', {
    id_dispositivo: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true, allowNull: false },
    id_usuario: {
      type: DataTypes.BIGINT,
      allowNull: false,
      references: { model: 'usuarios', key: 'id_usuario' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    token: { type: DataTypes.TEXT, allowNull: false, unique: true },
    plataforma: { type: DataTypes.STRING(15), allowNull: false },
    activo: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    fecha_registro: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    fecha_actualizacion: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
  await qi.sequelize.query(`
    ALTER TABLE dispositivos_push
    ADD CONSTRAINT dispositivos_push_plataforma_check
    CHECK (plataforma IN ('android', 'ios', 'web'))
  `);
  await qi.addIndex('dispositivos_push', ['id_usuario', 'activo'], {
    name: 'idx_dispositivos_push_usuario_activo',
  });
}

export async function down({ context: qi }) {
  await qi.dropTable('dispositivos_push');
}
