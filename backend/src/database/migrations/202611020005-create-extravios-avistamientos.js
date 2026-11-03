
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {

    // =====================================
    // REPORTES DE EXTRAVÍO
    // =====================================

    await qi.createTable('reportes_extravio', {
      id_reporte: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      id_mascota: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'mascotas',
          key: 'id_mascota',
        },
        onDelete: 'RESTRICT',
        onUpdate: 'CASCADE',
      },
      fecha_perdida: {
        type: DataTypes.DATE,
        allowNull: false,
      },
      fecha_reporte: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      ubicacion: {
        type: DataTypes.GEOGRAPHY('POINT', 4326),
        allowNull: true,
      },
      referencia_lugar: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      radio_km: {
        type: DataTypes.DECIMAL(5, 2),
        allowNull: false,
        defaultValue: 3,
      },
      estado: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'activo',
      },
      fecha_resolucion: {
        type: DataTypes.DATE,
        allowNull: true,
      },
    }, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE reportes_extravio
      ADD CONSTRAINT reportes_extravio_validos
      CHECK (
        (
          ubicacion IS NOT NULL OR
          NULLIF(BTRIM(referencia_lugar), '') IS NOT NULL
        )
        AND radio_km > 0
        AND radio_km <= 100
        AND estado IN ('activo', 'resuelto', 'cancelado')
      )
    `, { transaction });

    await qi.addIndex(
      'reportes_extravio',
      ['id_mascota'],
      {
        name: 'idx_reportes_mascota',
        transaction,
      }
    );

    await qi.sequelize.query(`
      CREATE INDEX idx_reportes_ubicacion
      ON reportes_extravio
      USING GIST (ubicacion)
    `, { transaction });

    // Una mascota no puede tener dos
    // reportes de extravío activos.
    await qi.sequelize.query(`
      CREATE UNIQUE INDEX uq_reportes_un_activo
      ON reportes_extravio (id_mascota)
      WHERE estado = 'activo'
    `, { transaction });

    await qi.sequelize.query(`
      CREATE INDEX idx_reportes_activos_fecha
      ON reportes_extravio (fecha_reporte DESC)
      WHERE estado = 'activo'
    `, { transaction });

    // =====================================
    // AVISTAMIENTOS
    // =====================================

    await qi.createTable('avistamientos', {
      id_avistamiento: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      id_usuario: {
        type: DataTypes.BIGINT,
        allowNull: true,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      },
      id_especie: {
        type: DataTypes.SMALLINT,
        allowNull: true,
        references: {
          model: 'especies',
          key: 'id_especie',
        },
        onDelete: 'RESTRICT',
        onUpdate: 'CASCADE',
      },
      fecha_avistamiento: {
        type: DataTypes.DATE,
        allowNull: false,
      },
      fecha_registro: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      ubicacion: {
        type: DataTypes.GEOGRAPHY('POINT', 4326),
        allowNull: true,
      },
      referencia_lugar: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      color_principal: {
        type: DataTypes.STRING(50),
        allowNull: true,
      },
      tamano: {
        type: DataTypes.STRING(20),
        allowNull: true,
      },
      senas_particulares: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      descripcion: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      estado: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'registrado',
      },
    }, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE avistamientos
      ADD CONSTRAINT avistamientos_validos
      CHECK (
        (
          ubicacion IS NOT NULL OR
          NULLIF(BTRIM(referencia_lugar), '') IS NOT NULL
        )
        AND (
          tamano IS NULL OR
          tamano IN ('pequeno', 'mediano', 'grande')
        )
        AND estado IN (
          'registrado',
          'revisado',
          'descartado'
        )
      )
    `, { transaction });

    await qi.addIndex(
      'avistamientos',
      ['id_usuario'],
      {
        name: 'idx_avistamientos_usuario',
        transaction,
      }
    );

    await qi.addIndex(
      'avistamientos',
      ['id_especie'],
      {
        name: 'idx_avistamientos_especie',
        transaction,
      }
    );

    await qi.addIndex(
      'avistamientos',
      ['fecha_avistamiento'],
      {
        name: 'idx_avistamientos_fecha',
        transaction,
      }
    );

    await qi.sequelize.query(`
      CREATE INDEX idx_avistamientos_ubicacion
      ON avistamientos
      USING GIST (ubicacion)
    `, { transaction });

    // =====================================
    // FOTOGRAFÍAS DE AVISTAMIENTOS
    // =====================================

    await qi.createTable('fotos_avistamientos', {
      id_foto: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      id_avistamiento: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'avistamientos',
          key: 'id_avistamiento',
        },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      url_original: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      url_recorte: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      tipo_captura: {
        type: DataTypes.STRING(15),
        allowNull: true,
      },
      estado_procesamiento: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'pendiente',
      },
      fecha_registro: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    }, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE fotos_avistamientos
      ADD CONSTRAINT fotos_avistamientos_validos
      CHECK (
        (
          tipo_captura IS NULL OR
          tipo_captura IN ('cerca', 'lejos', 'desconocida')
        )
        AND estado_procesamiento IN (
          'pendiente',
          'procesada',
          'fallida'
        )
      )
    `, { transaction });

    await qi.addIndex(
      'fotos_avistamientos',
      ['id_avistamiento'],
      {
        name: 'idx_fotos_avistamientos_avistamiento',
        transaction,
      }
    );

    // =====================================
    // COINCIDENCIAS
    // =====================================

    await qi.createTable('coincidencias', {
      id_coincidencia: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      id_avistamiento: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'avistamientos',
          key: 'id_avistamiento',
        },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      id_reporte: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'reportes_extravio',
          key: 'id_reporte',
        },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      metodo: {
        type: DataTypes.STRING(20),
        allowNull: false,
      },
      puntuacion: {
        type: DataTypes.DECIMAL(5, 4),
        allowNull: true,
      },
      estado_revision: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'pendiente',
      },
      fecha_deteccion: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    }, { transaction });

    await qi.addConstraint('coincidencias', {
      fields: ['id_avistamiento', 'id_reporte'],
      type: 'unique',
      name: 'uq_coincidencias_avistamiento_reporte',
      transaction,
    });

    await qi.sequelize.query(`
      ALTER TABLE coincidencias
      ADD CONSTRAINT coincidencias_validas
      CHECK (
        metodo IN ('visual', 'descripcion', 'mixto')
        AND (
          puntuacion IS NULL OR
          puntuacion BETWEEN 0 AND 1
        )
        AND estado_revision IN (
          'pendiente',
          'confirmada',
          'descartada'
        )
      )
    `, { transaction });

    await qi.addIndex(
      'coincidencias',
      ['id_reporte'],
      {
        name: 'idx_coincidencias_reporte',
        transaction,
      }
    );

  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.dropTable('coincidencias', {
      transaction,
    });

    await qi.dropTable('fotos_avistamientos', {
      transaction,
    });

    await qi.dropTable('avistamientos', {
      transaction,
    });

    await qi.dropTable('reportes_extravio', {
      transaction,
    });
  });
}
