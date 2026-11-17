import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.createTable('suscripciones_ubicacion', {
    id_usuario: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      allowNull: false,
      references: { model: 'usuarios', key: 'id_usuario' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    ubicacion: { type: DataTypes.GEOGRAPHY('POINT', 4326), allowNull: false },
    radio_km: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 10 },
    activa: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    fecha_actualizacion: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
  await qi.sequelize.query(`
    ALTER TABLE suscripciones_ubicacion
    ADD CONSTRAINT suscripciones_ubicacion_radio_check
    CHECK (radio_km > 0 AND radio_km <= 50)
  `);
  await qi.sequelize.query(`
    CREATE INDEX idx_suscripciones_ubicacion_gist
    ON suscripciones_ubicacion USING GIST (ubicacion)
  `);

  await qi.createTable('alertas_extravio_enviadas', {
    id_alerta: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true, allowNull: false },
    id_usuario: {
      type: DataTypes.BIGINT,
      allowNull: false,
      references: { model: 'usuarios', key: 'id_usuario' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    id_reporte: {
      type: DataTypes.BIGINT,
      allowNull: false,
      references: { model: 'reportes_extravio', key: 'id_reporte' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    fecha_envio: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
  await qi.addConstraint('alertas_extravio_enviadas', {
    fields: ['id_usuario', 'id_reporte'],
    type: 'unique',
    name: 'uq_alerta_extravio_usuario_reporte',
  });
}

export async function down({ context: qi }) {
  await qi.dropTable('alertas_extravio_enviadas');
  await qi.dropTable('suscripciones_ubicacion');
}
