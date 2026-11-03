
import { Umzug, SequelizeStorage } from 'umzug';
import { pathToFileURL } from 'node:url';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

import { sequelize } from './sequelize.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

export const migrator = new Umzug({
  migrations: {
    glob: 'src/database/migrations/*.js',

    resolve: ({ name, path, context }) => ({
      name,

      up: async () => {
        const migration = await import(
          pathToFileURL(path).href
        );
        return migration.up({ context });
      },

      down: async () => {
        const migration = await import(
          pathToFileURL(path).href
        );
        return migration.down({ context });
      },
    }),
  },

  context: sequelize.getQueryInterface(),

  storage: new SequelizeStorage({
    sequelize,
    tableName: 'SequelizeMeta',
  }),

  logger: console,
});
