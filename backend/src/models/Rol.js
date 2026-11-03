
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Rol = sequelize.define('Rol', {
  id_rol: {
    type: DataTypes.SMALLINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  nombre: {
    type: DataTypes.STRING(40),
    allowNull: false,
    unique: true,
  },
}, {
  tableName: 'roles',
  timestamps: false,
});
