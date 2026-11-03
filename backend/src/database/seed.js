
import { sequelize } from '../config/sequelize.js';

import { seedRoles } from './seeds/001-roles.seed.js';
import { seedEspecies } from './seeds/002-especies.seed.js';
import { seedRazas } from './seeds/003-razas.seed.js';

async function ejecutarSeeds() {
  try {
    await sequelize.authenticate();

    await sequelize.transaction(async (transaction) => {
      console.log('Cargando roles...');
      await seedRoles(sequelize, transaction);

      console.log('Cargando especies...');
      await seedEspecies(sequelize, transaction);

      console.log('Cargando razas...');
      await seedRazas(sequelize, transaction);
    });

    console.log('Seeds de PetID ejecutados correctamente');
  } catch (error) {
    console.error('Error al ejecutar los seeds:', error);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

ejecutarSeeds();
