import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Notificacion = sequelize.define('Notificacion', {
  id_notificacion: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  id_usuario: { type: DataTypes.BIGINT, allowNull: false },
  tipo: { type: DataTypes.STRING(40), allowNull: false },
  titulo: { type: DataTypes.STRING(160), allowNull: false },
  mensaje: { type: DataTypes.TEXT, allowNull: false },
  datos: { type: DataTypes.JSONB, allowNull: true },
  leida: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
  fecha_creacion: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
}, {
  tableName: 'notificaciones',
  timestamps: false,
});
