
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Avistamiento = sequelize.define('Avistamiento', {
  id_avistamiento: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  id_usuario: {
    type: DataTypes.BIGINT,
    allowNull: true,
    references: {
      model: 'usuarios',
      key: 'id_usuario',
    },
  },

  id_especie: {
    type: DataTypes.SMALLINT,
    allowNull: true,
    references: {
      model: 'especies',
      key: 'id_especie',
    },
  },

  fecha_avistamiento: {
    type: DataTypes.DATE,
    allowNull: false,
  },

  fecha_registro: {
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

  color_principal: {
    type: DataTypes.STRING(50),
    allowNull: true,
  },

  tamano: {
    type: DataTypes.STRING(20),
    allowNull: true,
    validate: {
      isIn: [['pequeno', 'mediano', 'grande']],
    },
  },

  senas_particulares: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  descripcion: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  estado: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'registrado',
    validate: {
      isIn: [['registrado', 'revisado', 'descartado']],
    },
  },
}, {
  tableName: 'avistamientos',
  timestamps: false,
});
