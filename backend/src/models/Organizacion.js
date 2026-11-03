
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Organizacion = sequelize.define('Organizacion', {
  id_organizacion: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  nombre: {
    type: DataTypes.STRING(150),
    allowNull: false,
  },

  tipo: {
    type: DataTypes.STRING(20),
    allowNull: false,
    validate: {
      isIn: [['veterinaria', 'refugio']],
    },
  },

  direccion: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  telefono: {
    type: DataTypes.STRING(20),
    allowNull: true,
  },

  verificada: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },
}, {
  tableName: 'organizaciones',
  timestamps: false,
});
