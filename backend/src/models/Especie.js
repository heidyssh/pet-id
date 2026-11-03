
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Especie = sequelize.define('Especie', {
  id_especie: {
    type: DataTypes.SMALLINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  nombre: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true,
  },
}, {
  tableName: 'especies',
  timestamps: false,
});
