
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const SolicitudAdopcion = sequelize.define(
  'SolicitudAdopcion',
  {
    id_solicitud: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true,
      allowNull: false,
    },

    id_publicacion: {
      type: DataTypes.BIGINT,
      allowNull: false,
      references: {
        model: 'publicaciones_adopcion',
        key: 'id_publicacion',
      },
    },

    id_usuario: {
      type: DataTypes.BIGINT,
      allowNull: false,
      references: {
        model: 'usuarios',
        key: 'id_usuario',
      },
    },

    mensaje: {
      type: DataTypes.TEXT,
      allowNull: true,
    },

    fecha_solicitud: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },

    estado: {
      type: DataTypes.STRING(20),
      allowNull: false,
      defaultValue: 'pendiente',
      validate: {
        isIn: [[
          'pendiente',
          'aprobada',
          'rechazada',
          'cancelada',
        ]],
      },
    },
  },
  {
    tableName: 'solicitudes_adopcion',
    timestamps: false,
  }
);
