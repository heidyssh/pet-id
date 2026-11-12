import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.createTable('notificaciones', {
    id_notificacion: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true, allowNull: false },
    id_usuario: {
      type: DataTypes.BIGINT, allowNull: false,
      references: { model: 'usuarios', key: 'id_usuario' },
      onUpdate: 'CASCADE', onDelete: 'CASCADE',
    },
    tipo: { type: DataTypes.STRING(40), allowNull: false },
    titulo: { type: DataTypes.STRING(160), allowNull: false },
    mensaje: { type: DataTypes.TEXT, allowNull: false },
    datos: { type: DataTypes.JSONB, allowNull: true },
    leida: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
    fecha_creacion: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
  await qi.addIndex('notificaciones', ['id_usuario', 'leida', 'fecha_creacion'], {
    name: 'idx_notificaciones_usuario_estado_fecha',
  });
}

export async function down({ context: qi }) {
  await qi.dropTable('notificaciones');
}
