
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {

    // =====================================
    // SESIONES DE USUARIO
    // =====================================

    await qi.createTable('sesiones_usuario', {
      id_sesion: {
        type: DataTypes.UUID,
        primaryKey: true,
        allowNull: false,
      },

      id_usuario: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },

      refresh_hash: {
        type: DataTypes.STRING(64),
        allowNull: false,
        unique: true,
      },

      agente_usuario: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },

      fecha_creacion: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },

      ultimo_uso: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },

      fecha_expiracion: {
        type: DataTypes.DATE,
        allowNull: false,
      },

      fecha_revocacion: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    }, { transaction });

    await qi.addIndex('sesiones_usuario', [
      'id_usuario',
      'fecha_revocacion',
    ], {
      name: 'idx_sesiones_usuario_estado',
      transaction,
    });

    await qi.addIndex('sesiones_usuario', [
      'fecha_expiracion',
    ], {
      name: 'idx_sesiones_expiracion',
      transaction,
    });

    // =====================================
    // REFRESH TOKENS UTILIZADOS
    // =====================================

    await qi.createTable('refresh_tokens_usados', {
      token_hash: {
        type: DataTypes.STRING(64),
        primaryKey: true,
        allowNull: false,
      },

      id_sesion: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
          model: 'sesiones_usuario',
          key: 'id_sesion',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },

      fecha_uso: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    }, { transaction });

    await qi.addIndex('refresh_tokens_usados', [
      'id_sesion',
    ], {
      name: 'idx_refresh_usados_sesion',
      transaction,
    });
  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.dropTable('refresh_tokens_usados', {
      transaction,
    });

    await qi.dropTable('sesiones_usuario', {
      transaction,
    });
  });
}
