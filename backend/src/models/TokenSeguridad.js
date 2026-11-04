
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const TokenSeguridad = sequelize.define(
  'TokenSeguridad',
  {
    id_token: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true,
    },
    id_usuario: {
      type: DataTypes.BIGINT,
      allowNull: false,
    },
    tipo: {
      type: DataTypes.STRING(20),
      allowNull: false,
      validate: {
        isIn: [['verificacion', 'recuperacion']],
      },
    },
    token_hash: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },
    fecha_expiracion: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    fecha_consumo: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    fecha_creacion: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'tokens_seguridad',
    timestamps: false,
  }
);
