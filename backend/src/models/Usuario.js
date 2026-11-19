
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Usuario = sequelize.define('Usuario', {
  id_usuario: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  nombre: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },

  apellido: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },

  dni: {
    type: DataTypes.STRING(20),
    allowNull: true,
    unique: true,
  },

  telefono: {
    type: DataTypes.STRING(20),
    allowNull: true,
  },

  correo: {
    type: DataTypes.STRING(150),
    allowNull: false,
    unique: true,
    validate: {
      isEmail: true,
    },
  },

  password_hash: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  google_sub: {
    type: DataTypes.STRING(255),
    allowNull: true,
    unique: true,
  },

  fecha_registro: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },

  activo: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },

    correo_verificado: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },

  token_version: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
}, {
  tableName: 'usuarios',
  timestamps: false,

  defaultScope: {
    attributes: {
      exclude: ['password_hash', 'google_sub'],
    },
  },

  scopes: {
    withPassword: {},
    withGoogleIdentity: { attributes: { exclude: ['password_hash'] } },
  },
});
