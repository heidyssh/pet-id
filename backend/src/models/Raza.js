
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Raza = sequelize.define('Raza', {
  id_raza: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  id_especie: {
    type: DataTypes.SMALLINT,
    allowNull: false,

    references: {
      model: 'especies',
      key: 'id_especie',
    },
  },

  nombre: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },
}, {
  tableName: 'razas',
  timestamps: false,

  indexes: [
    {
      name: 'razas_especie_nombre_unique',
      unique: true,
      fields: ['id_especie', 'nombre'],
    },
  ],
});
