import { DataTypes } from 'sequelize';

export async function up({ context: queryInterface }) {
  const transaction = await queryInterface.sequelize.transaction();
  try {
    await queryInterface.addColumn('usuarios', 'foto_perfil_url', {
      type: DataTypes.TEXT,
      allowNull: true,
    }, { transaction });
    await queryInterface.addColumn('usuarios', 'foto_perfil_proveedor', {
      type: DataTypes.STRING(20),
      allowNull: true,
    }, { transaction });
    await queryInterface.addColumn('usuarios', 'foto_perfil_id', {
      type: DataTypes.TEXT,
      allowNull: true,
    }, { transaction });
    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}

export async function down({ context: queryInterface }) {
  const transaction = await queryInterface.sequelize.transaction();
  try {
    await queryInterface.removeColumn('usuarios', 'foto_perfil_id', { transaction });
    await queryInterface.removeColumn('usuarios', 'foto_perfil_proveedor', { transaction });
    await queryInterface.removeColumn('usuarios', 'foto_perfil_url', { transaction });
    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}
