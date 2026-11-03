
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const ReporteExtravio = sequelize.define('ReporteExtravio', {
  id_reporte: {
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

  fecha_perdida: {
    type: DataTypes.DATE,
    allowNull: false,
  },

  fecha_reporte: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },

  ubicacion: {
    type: DataTypes.GEOGRAPHY('POINT', 4326),
    allowNull: true,
  },

  referencia_lugar: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  radio_km: {
    type: DataTypes.DECIMAL(5, 2),
    allowNull: false,
    defaultValue: 3,
    validate: {
      min: 0.01,
      max: 100,
    },
  },

  estado: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'activo',
    validate: {
      isIn: [['activo', 'resuelto', 'cancelado']],
    },
  },

  fecha_resolucion: {
    type: DataTypes.DATE,
    allowNull: true,
  },
}, {
  tableName: 'reportes_extravio',
  timestamps: false,
});
