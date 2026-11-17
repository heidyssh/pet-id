import { DataTypes } from 'sequelize';

const TABLAS = ['fotos_mascotas', 'fotos_avistamientos'];

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    for (const tabla of TABLAS) {
      await qi.addColumn(tabla, 'proveedor_almacenamiento', {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'local',
      }, { transaction });
      await qi.addColumn(tabla, 'id_almacenamiento_original', {
        type: DataTypes.TEXT,
        allowNull: true,
      }, { transaction });
      await qi.addColumn(tabla, 'id_almacenamiento_recorte', {
        type: DataTypes.TEXT,
        allowNull: true,
      }, { transaction });
      await qi.addConstraint(tabla, {
        fields: ['proveedor_almacenamiento'],
        type: 'check',
        where: { proveedor_almacenamiento: ['local', 'cloudinary'] },
        name: `${tabla}_proveedor_almacenamiento_check`,
        transaction,
      });
    }
  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    for (const tabla of [...TABLAS].reverse()) {
      await qi.removeConstraint(tabla, `${tabla}_proveedor_almacenamiento_check`, { transaction });
      await qi.removeColumn(tabla, 'id_almacenamiento_recorte', { transaction });
      await qi.removeColumn(tabla, 'id_almacenamiento_original', { transaction });
      await qi.removeColumn(tabla, 'proveedor_almacenamiento', { transaction });
    }
  });
}

