
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {

    // ==========================================
    // PUBLICACIONES DE ADOPCIÓN
    // ==========================================

    await qi.createTable('publicaciones_adopcion', {
      id_publicacion: {
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
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },

      id_organizacion: {
        type: DataTypes.BIGINT,
        allowNull: true,
        references: {
          model: 'organizaciones',
          key: 'id_organizacion',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },

      descripcion: {
        type: DataTypes.TEXT,
        allowNull: false,
      },

      fecha_publicacion: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },

      estado: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'disponible',
      },
    }, { transaction });

    // Validar los estados permitidos.
    // Evitar crear una restricción duplicada.

    await qi.sequelize.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conname = 'publicaciones_adopcion_estado_check'
            AND conrelid = 'publicaciones_adopcion'::regclass
        ) THEN
          ALTER TABLE publicaciones_adopcion
          ADD CONSTRAINT publicaciones_adopcion_estado_check
          CHECK (
            estado IN (
              'disponible',
              'cerrada',
              'cancelada'
            )
          );
        END IF;
      END
      $$;
    `, { transaction });

    // Una mascota no puede tener dos
    // publicaciones disponibles simultáneamente.

    await qi.sequelize.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS
      publicaciones_adopcion_activa_unique
      ON publicaciones_adopcion (id_mascota)
      WHERE estado = 'disponible';
    `, { transaction });

    // Índice para búsquedas por organización.

    await qi.sequelize.query(`
      CREATE INDEX IF NOT EXISTS
      publicaciones_adopcion_organizacion_idx
      ON publicaciones_adopcion (id_organizacion);
    `, { transaction });

    // ==========================================
    // SOLICITUDES DE ADOPCIÓN
    // ==========================================

    await qi.createTable('solicitudes_adopcion', {
      id_solicitud: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },

      id_publicacion: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'publicaciones_adopcion',
          key: 'id_publicacion',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },

      id_usuario: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },

      mensaje: {
        type: DataTypes.TEXT,
        allowNull: true,
      },

      fecha_solicitud: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },

      estado: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'pendiente',
      },
    }, { transaction });

    // Validar los estados de solicitudes.

    await qi.sequelize.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conname = 'solicitudes_adopcion_estado_check'
            AND conrelid = 'solicitudes_adopcion'::regclass
        ) THEN
          ALTER TABLE solicitudes_adopcion
          ADD CONSTRAINT solicitudes_adopcion_estado_check
          CHECK (
            estado IN (
              'pendiente',
              'aprobada',
              'rechazada',
              'cancelada'
            )
          );
        END IF;
      END
      $$;
    `, { transaction });

    // Evitar solicitudes duplicadas del mismo
    // usuario para una misma publicación.

    await qi.sequelize.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conname = 'solicitudes_adopcion_usuario_unique'
            AND conrelid = 'solicitudes_adopcion'::regclass
        ) THEN
          ALTER TABLE solicitudes_adopcion
          ADD CONSTRAINT solicitudes_adopcion_usuario_unique
          UNIQUE (id_publicacion, id_usuario);
        END IF;
      END
      $$;
    `, { transaction });

    // Índice para consultar solicitudes por usuario.

    await qi.sequelize.query(`
      CREATE INDEX IF NOT EXISTS
      solicitudes_adopcion_usuario_idx
      ON solicitudes_adopcion (id_usuario);
    `, { transaction });

  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {

    await qi.dropTable('solicitudes_adopcion', {
      transaction,
    });

    await qi.dropTable('publicaciones_adopcion', {
      transaction,
    });

  });
}
