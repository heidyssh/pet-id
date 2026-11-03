
import { Sequelize } from 'sequelize';
import { env } from './config.js';

export const sequelize = new Sequelize(env.DATABASE_URL, {
  dialect: 'postgres',
  logging: false,

  pool: {
    max: env.DB_POOL_MAX,
    min: 0,
    acquire: 30000,
    idle: 10000,
  },

  define: {
    freezeTableName: true,
    timestamps: false,
  },
});

export async function verificarConexion() {
  await sequelize.authenticate();

  const [resultados] = await sequelize.query(`
    SELECT
      current_database() AS database,
      PostGIS_Version() AS postgis
  `);

  console.log('PostgreSQL conectado correctamente');
  console.log('Base de datos:', resultados[0].database);
  console.log('PostGIS:', resultados[0].postgis);
}
