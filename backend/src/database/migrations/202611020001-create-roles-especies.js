
import { DataTypes } from 'sequelize';

export async function up({ context: queryInterface }) {
  const transaction = await queryInterface.sequelize.transaction();

  try {
    await queryInterface.createTable(
      'roles',
      {
        id_rol: {
          type: DataTypes.SMALLINT,
          primaryKey: true,
          autoIncrement: true,
          allowNull: false,
        },

        nombre: {
          type: DataTypes.STRING(40),
          allowNull: false,
          unique: true,
        },
      },
      { transaction }
    );

    await queryInterface.createTable(
      'especies',
      {
        id_especie: {
          type: DataTypes.SMALLINT,
          primaryKey: true,
          autoIncrement: true,
          allowNull: false,
        },

        nombre: {
          type: DataTypes.STRING(50),
          allowNull: false,
          unique: true,
        },
      },
      { transaction }
    );

    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}

export async function down({ context: queryInterface }) {
  const transaction = await queryInterface.sequelize.transaction();

  try {
    await queryInterface.dropTable('especies', {
      transaction,
    });

    await queryInterface.dropTable('roles', {
      transaction,
    });

    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}
