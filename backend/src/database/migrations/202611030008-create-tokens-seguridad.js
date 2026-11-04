
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.addColumn('usuarios', 'correo_verificado', {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    }, { transaction });

    await qi.addColumn('usuarios', 'token_version', {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    }, { transaction });

    await qi.createTable('tokens_seguridad', {
      id_token: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },

      id_usuario: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },

      tipo: {
        type: DataTypes.STRING(20),
        allowNull: false,
      },

      token_hash: {
        type: DataTypes.STRING(64),
        allowNull: false,
        unique: true,
      },

      fecha_expiracion: {
        type: DataTypes.DATE,
        allowNull: false,
      },

      fecha_consumo: {
        type: DataTypes.DATE,
        allowNull: true,
      },

      fecha_creacion: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    }, { transaction });

    await qi.addConstraint('tokens_seguridad', {
      fields: ['tipo'],
      type: 'check',
      where: {
        tipo: ['verificacion', 'recuperacion'],
      },
      name: 'tokens_seguridad_tipo_check',
      transaction,
    });

    await qi.addIndex(
      'tokens_seguridad',
      ['id_usuario', 'tipo'],
      {
        name: 'idx_tokens_seguridad_usuario_tipo',
        transaction,
      }
    );
  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.dropTable('tokens_seguridad', { transaction });

    await qi.removeColumn(
      'usuarios',
      'token_version',
      { transaction }
    );

    await qi.removeColumn(
      'usuarios',
      'correo_verificado',
      { transaction }
    );
  });
}
