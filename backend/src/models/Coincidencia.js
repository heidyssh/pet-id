
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Coincidencia = sequelize.define('Coincidencia', {
  id_coincidencia: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  id_avistamiento: {
    type: DataTypes.BIGINT,
    allowNull: false,
    references: {
      model: 'avistamientos',
      key: 'id_avistamiento',
    },
  },

  id_reporte: {
    type: DataTypes.BIGINT,
    allowNull: false,
    references: {
      model: 'reportes_extravio',
      key: 'id_reporte',
    },
  },

  metodo: {
    type: DataTypes.STRING(20),
    allowNull: false,
    validate: {
      isIn: [['visual', 'descripcion', 'mixto']],
    },
  },

  puntuacion: {
    type: DataTypes.DECIMAL(5, 4),
    allowNull: true,
    validate: {
      min: 0,
      max: 1,
    },
  },

  estado_revision: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'pendiente',
    validate: {
      isIn: [['pendiente', 'confirmada', 'descartada']],
    },
  },

  fecha_deteccion: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'coincidencias',
  timestamps: false,
});
