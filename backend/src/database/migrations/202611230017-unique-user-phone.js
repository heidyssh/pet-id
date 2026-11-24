export async function up({ context: queryInterface }) {
  await queryInterface.addIndex('usuarios', ['telefono'], {
    name: 'usuarios_telefono_unique',
    unique: true,
  });
}

export async function down({ context: queryInterface }) {
  await queryInterface.removeIndex('usuarios', 'usuarios_telefono_unique');
}
