import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const VectorVisual = sequelize.define('VectorVisual', {
  id_vector: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },
  id_foto_mascota: {
    type: DataTypes.BIGINT,
    allowNull: true,
  },
  id_foto_avistamiento: {
    type: DataTypes.BIGINT,
    allowNull: true,
  },
  vector: {
    type: DataTypes.ARRAY(DataTypes.REAL),
    allowNull: false,
  },
  modelo: {
    type: DataTypes.STRING(160),
    allowNull: false,
  },
  dimensiones: {
    type: DataTypes.SMALLINT,
    allowNull: false,
  },
  fecha_creacion: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'vectores_visuales',
  timestamps: false,
});
