import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const DispositivoPush = sequelize.define('DispositivoPush', {
  id_dispositivo: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true, allowNull: false },
  id_usuario: { type: DataTypes.BIGINT, allowNull: false },
  token: { type: DataTypes.TEXT, allowNull: false, unique: true },
  plataforma: { type: DataTypes.STRING(15), allowNull: false },
  activo: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
  fecha_registro: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  fecha_actualizacion: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
}, {
  tableName: 'dispositivos_push',
  timestamps: false,
});
