
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const RefreshTokenUsado = sequelize.define(
  'RefreshTokenUsado',
  {
    token_hash: {
      type: DataTypes.STRING(64),
      primaryKey: true,
      allowNull: false,
    },

    id_sesion: {
      type: DataTypes.UUID,
      allowNull: false,
    },

    fecha_uso: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'refresh_tokens_usados',
    timestamps: false,
  }
);
