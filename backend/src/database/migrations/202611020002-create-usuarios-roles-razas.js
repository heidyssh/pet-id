
import { DataTypes } from 'sequelize';

export async function up({ context: queryInterface }) {
  const transaction = await queryInterface.sequelize.transaction();

  try {
    await queryInterface.createTable('usuarios', {
      id_usuario: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      nombre: {
        type: DataTypes.STRING(100),
        allowNull: false,
      },
      apellido: {
        type: DataTypes.STRING(100),
        allowNull: false,
      },
      dni: {
        type: DataTypes.STRING(20),
        unique: true,
        allowNull: true,
      },
      telefono: {
        type: DataTypes.STRING(20),
        allowNull: true,
      },
      correo: {
        type: DataTypes.STRING(150),
        unique: true,
        allowNull: false,
      },
      password_hash: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      fecha_registro: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      activo: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
    }, { transaction });

    await queryInterface.createTable('usuario_roles', {
      id_usuario: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      id_rol: {
        type: DataTypes.SMALLINT,
        primaryKey: true,
        allowNull: false,
        references: {
          model: 'roles',
          key: 'id_rol',
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },
    }, { transaction });

    await queryInterface.createTable('razas', {
      id_raza: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      id_especie: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        references: {
          model: 'especies',
          key: 'id_especie',
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },
      nombre: {
        type: DataTypes.STRING(100),
        allowNull: false,
      },
    }, { transaction });

    await queryInterface.addConstraint('razas', {
      fields: ['id_especie', 'nombre'],
      type: 'unique',
      name: 'razas_especie_nombre_unique',
      transaction,
    });

    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}

export async function down({ context: queryInterface }) {
  const transaction = await queryInterface.sequelize.transaction();

  try {
    await queryInterface.dropTable('usuario_roles', { transaction });
    await queryInterface.dropTable('razas', { transaction });
    await queryInterface.dropTable('usuarios', { transaction });

    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}
