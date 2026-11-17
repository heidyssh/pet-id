import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const AlertaExtravioEnviada = sequelize.define('AlertaExtravioEnviada', {
  id_alerta: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true, allowNull: false },
  id_usuario: { type: DataTypes.BIGINT, allowNull: false },
  id_reporte: { type: DataTypes.BIGINT, allowNull: false },
  fecha_envio: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
}, {
  tableName: 'alertas_extravio_enviadas',
  timestamps: false,
});
