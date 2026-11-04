
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const SesionUsuario = sequelize.define(
  'SesionUsuario',
  {
    id_sesion: {
      type: DataTypes.UUID,
      primaryKey: true,
      allowNull: false,
    },

    id_usuario: {
      type: DataTypes.BIGINT,
      allowNull: false,
    },

    refresh_hash: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },

    agente_usuario: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },

    fecha_creacion: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },

    ultimo_uso: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },

    fecha_expiracion: {
      type: DataTypes.DATE,
      allowNull: false,
    },

    fecha_revocacion: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'sesiones_usuario',
    timestamps: false,
  }
);
