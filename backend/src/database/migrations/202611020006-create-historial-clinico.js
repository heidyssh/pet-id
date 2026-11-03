
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {

    await qi.createTable('historial_clinico', {
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
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },

      id_organizacion: {
        type: DataTypes.BIGINT,
        allowNull: true,
        references: {
          model: 'organizaciones',
          key: 'id_organizacion',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },

      id_usuario_registro: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },

      tipo_registro: {
        type: DataTypes.STRING(25),
        allowNull: false,
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
    }, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE historial_clinico
      ADD CONSTRAINT historial_clinico_tipo_check
      CHECK (
        tipo_registro IN (
          'vacuna',
          'desparasitacion',
          'consulta',
          'tratamiento'
        )
      )
    `, { transaction });

    await qi.addIndex(
      'historial_clinico',
      ['id_mascota'],
      {
        name: 'idx_historial_mascota',
        transaction,
      }
    );

    await qi.addIndex(
      'historial_clinico',
      ['id_organizacion'],
      {
        name: 'idx_historial_organizacion',
        transaction,
      }
    );
  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.dropTable('historial_clinico', {
      transaction,
    });
  });
}
