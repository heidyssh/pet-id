
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const HistorialClinico = sequelize.define('HistorialClinico', {
  id_historial: {
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

  id_usuario_registro: {
    type: DataTypes.BIGINT,
    allowNull: false,
    references: {
      model: 'usuarios',
      key: 'id_usuario',
    },
  },

  tipo_registro: {
    type: DataTypes.STRING(25),
    allowNull: false,
    validate: {
      isIn: [[
        'vacuna',
        'desparasitacion',
        'consulta',
        'tratamiento',
      ]],
    },
  },

  descripcion: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  fecha_aplicacion: {
    type: DataTypes.DATEONLY,
    allowNull: false,
  },

  proxima_fecha: {
    type: DataTypes.DATEONLY,
    allowNull: true,
  },
}, {
  tableName: 'historial_clinico',
  timestamps: false,
});
