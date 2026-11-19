import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.addColumn('usuarios', 'google_sub', {
    type: DataTypes.STRING(255),
    allowNull: true,
    unique: true,
  });
}

export async function down({ context: qi }) {
  await qi.removeColumn('usuarios', 'google_sub');
}
