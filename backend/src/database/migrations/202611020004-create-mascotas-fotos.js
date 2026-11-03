
import { DataTypes } from 'sequelize';

export async function up({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {

    // Garantiza que la raza pertenezca
    // a la especie de la mascota.
    await qi.addConstraint('razas', {
      fields: ['id_raza', 'id_especie'],
      type: 'unique',
      name: 'razas_id_especie_unique',
      transaction,
    });

    await qi.createTable('mascotas', {
      id_mascota: {
        type: DataTypes.BIGINT,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false,
      },
      id_dueno: {
        type: DataTypes.BIGINT,
        allowNull: false,
        references: {
          model: 'usuarios',
          key: 'id_usuario',
        },
        onDelete: 'RESTRICT',
        onUpdate: 'CASCADE',
      },
      id_especie: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        references: {
          model: 'especies',
          key: 'id_especie',
        },
        onDelete: 'RESTRICT',
        onUpdate: 'CASCADE',
      },
      id_raza: {
        type: DataTypes.BIGINT,
        allowNull: true,
      },
      nombre: {
        type: DataTypes.STRING(100),
        allowNull: false,
      },
      sexo: {
        type: DataTypes.STRING(15),
        allowNull: true,
      },
      color_principal: {
        type: DataTypes.STRING(50),
        allowNull: false,
      },
      tamano: {
        type: DataTypes.STRING(20),
        allowNull: true,
      },
      senas_particulares: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      fecha_nacimiento: {
        type: DataTypes.DATEONLY,
        allowNull: true,
      },
      estado: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: 'a_salvo',
      },
      fecha_registro: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    }, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE mascotas
      ADD CONSTRAINT mascotas_raza_especie_fk
      FOREIGN KEY (id_raza, id_especie)
      REFERENCES razas (id_raza, id_especie)
      ON UPDATE CASCADE
      ON DELETE RESTRICT
    `, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE mascotas
      ADD CONSTRAINT mascotas_estado_check
      CHECK (
        estado IN ('a_salvo', 'perdido', 'en_adopcion')
      )
    `, { transaction });

    await qi.sequelize.query(`
      ALTER TABLE mascotas
      ADD CONSTRAINT mascotas_tamano_check
      CHECK (
        tamano IS NULL OR
        tamano IN ('pequeno', 'mediano', 'grande')
      )
    `, { transaction });

    await qi.createTable('fotos_mascotas', {
      id_foto: {
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
      es_principal: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      fecha_registro: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    }, { transaction });

    await qi.addIndex('mascotas', ['id_dueno'], {
      name: 'idx_mascotas_dueno',
      transaction,
    });

    await qi.addIndex(
      'mascotas',
      ['id_raza', 'id_especie'],
      {
        name: 'idx_mascotas_raza_especie',
        transaction,
      }
    );

    await qi.addIndex(
      'fotos_mascotas',
      ['id_mascota'],
      {
        name: 'idx_fotos_mascotas_mascota',
        transaction,
      }
    );

    // Máximo una foto principal por mascota.
    await qi.sequelize.query(`
      CREATE UNIQUE INDEX uq_fotos_mascotas_principal
      ON fotos_mascotas (id_mascota)
      WHERE es_principal = TRUE
    `, { transaction });
  });
}

export async function down({ context: qi }) {
  await qi.sequelize.transaction(async (transaction) => {
    await qi.dropTable('fotos_mascotas', {
      transaction,
    });

    await qi.dropTable('mascotas', {
      transaction,
    });

    await qi.removeConstraint(
      'razas',
      'razas_id_especie_unique',
      { transaction }
    );
  });
}
