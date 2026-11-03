
import { DataTypes } from 'sequelize';
import { sequelize } from '../config/sequelize.js';

export const Mascota = sequelize.define('Mascota', {
  id_mascota: {
    type: DataTypes.BIGINT,
    primaryKey: true,
    autoIncrement: true,
    allowNull: false,
  },

  id_dueno: {
    type: DataTypes.BIGINT,
    allowNull: false,
    references: {
      model: 'usuarios',
      key: 'id_usuario',
    },
  },

  id_especie: {
    type: DataTypes.SMALLINT,
    allowNull: false,
    references: {
      model: 'especies',
      key: 'id_especie',
    },
  },

  id_raza: {
    type: DataTypes.BIGINT,
    allowNull: true,
  },

  nombre: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },

  sexo: {
    type: DataTypes.STRING(15),
    allowNull: true,
  },

  color_principal: {
    type: DataTypes.STRING(50),
    allowNull: false,
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

  fecha_nacimiento: {
    type: DataTypes.DATEONLY,
    allowNull: true,
  },

  estado: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'a_salvo',
    validate: {
      isIn: [['a_salvo', 'perdido', 'en_adopcion']],
    },
  },

  fecha_registro: {
    type: DataTypes.DATE,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
}, {
  tableName: 'mascotas',
  timestamps: false,
});
