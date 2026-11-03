
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const PublicacionAdopcion = sequelize.define(
  'PublicacionAdopcion',
  {
    id_publicacion: {
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

    id_organizacion: {
      type: DataTypes.BIGINT,
      allowNull: true,
      references: {
        model: 'organizaciones',
        key: 'id_organizacion',
      },
    },

    descripcion: {
      type: DataTypes.TEXT,
      allowNull: false,
    },

    fecha_publicacion: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },

    estado: {
      type: DataTypes.STRING(20),
      allowNull: false,
      defaultValue: 'disponible',
      validate: {
        isIn: [['disponible', 'cerrada', 'cancelada']],
      },
    },
  },
  {
    tableName: 'publicaciones_adopcion',
    timestamps: false,
  }
);
