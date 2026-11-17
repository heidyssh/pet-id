
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const FotoAvistamiento = sequelize.define('FotoAvistamiento', {
  id_foto: {
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

  url_original: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  url_recorte: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  proveedor_almacenamiento: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'local',
  },

  id_almacenamiento_original: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  id_almacenamiento_recorte: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  tipo_captura: {
    type: DataTypes.STRING(15),
    allowNull: true,
    validate: {
      isIn: [['cerca', 'lejos', 'desconocida']],
    },
  },

  estado_procesamiento: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'pendiente',
    validate: {
      isIn: [['pendiente', 'procesada', 'fallida']],
    },
  },

  fecha_registro: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'fotos_avistamientos',
  timestamps: false,
});
