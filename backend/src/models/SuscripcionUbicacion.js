import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const SuscripcionUbicacion = sequelize.define('SuscripcionUbicacion', {
  id_usuario: { type: DataTypes.BIGINT, primaryKey: true, allowNull: false },
  ubicacion: { type: DataTypes.GEOGRAPHY('POINT', 4326), allowNull: false },
  radio_km: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 10 },
  activa: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
  fecha_actualizacion: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
}, {
  tableName: 'suscripciones_ubicacion',
  timestamps: false,
});
