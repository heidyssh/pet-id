
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const UsuarioOrganizacion = sequelize.define(
  'UsuarioOrganizacion',
  {
    id_usuario: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      allowNull: false,
      references: {
        model: 'usuarios',
        key: 'id_usuario',
      },
    },

    id_organizacion: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      allowNull: false,
      references: {
        model: 'organizaciones',
        key: 'id_organizacion',
      },
    },

    cargo: {
      type: DataTypes.STRING(80),
      allowNull: true,
    },

    activo: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'usuario_organizaciones',
    timestamps: false,
  }
);
