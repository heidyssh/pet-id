
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const FotoMascota = sequelize.define('FotoMascota', {
  id_foto: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  id_mascota: {
    type: DataTypes.BIGINT,
    allowNull: false,
    references: {
      model: 'mascotas',
      key: 'id_mascota',
    },
  },

  url_original: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  url_recorte: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  es_principal: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },

  fecha_registro: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'fotos_mascotas',
  timestamps: false,
});
