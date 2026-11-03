
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.createTable('organizaciones', {
      id_organizacion: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      nombre: {
        type: DataTypes.STRING(150),
        allowNull: false,
      },
      tipo: {
        type: DataTypes.STRING(20),
        allowNull: false,
      },
      direccion: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      telefono: {
        type: DataTypes.STRING(20),
        allowNull: true,
      },
      verificada: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
    }, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE organizaciones
      ADD CONSTRAINT organizaciones_tipo_check
      CHECK (tipo IN ('veterinaria', 'refugio'))
    `, { transaction });

    await qi.createTable('usuario_organizaciones', {
      id_usuario: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      id_organizacion: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        allowNull: false,
        references: {
          model: 'organizaciones',
          key: 'id_organizacion',
        },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      cargo: {
        type: DataTypes.STRING(80),
        allowNull: true,
      },
      activo: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
    }, { transaction });

    await qi.addIndex(
      'usuario_organizaciones',
      ['id_organizacion'],
      {
        name: 'idx_usuario_organizaciones_org',
        transaction,
      }
    );
  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.dropTable('usuario_organizaciones', {
      transaction,
    });

    await qi.dropTable('organizaciones', {
      transaction,
    });
  });
}
