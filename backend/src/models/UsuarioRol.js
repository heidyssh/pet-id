
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const UsuarioRol = sequelize.define('UsuarioRol', {
  id_usuario: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    allowNull: false,

    references: {
      model: 'usuarios',
      key: 'id_usuario',
    },
  },

  id_rol: {
    type: DataTypes.SMALLINT,
    primaryKey: true,
    allowNull: false,

    references: {
      model: 'roles',
      key: 'id_rol',
    },
  },
}, {
  tableName: 'usuario_roles',
  timestamps: false,
});
