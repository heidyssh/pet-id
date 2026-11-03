
import { migrator } from '../config/migrator.js';
import { sequelize } from '../config/sequelize.js';

const comando = process.argv[2] || 'up';

async function ejecutar() {
  try {
    await sequelize.authenticate();

    switch (comando) {
      case 'up':
        await migrator.up();
        console.log('Migraciones aplicadas correctamente');
        break;

      case 'down':
        await migrator.down();
        console.log('Ultima migracion revertida');
        break;

      case 'status': {
        const ejecutadas = await migrator.executed();
        const pendientes = await migrator.pending();

        console.log('Ejecutadas:', ejecutadas.map(m => m.name));
        console.log('Pendientes:', pendientes.map(m => m.name));
        break;
      }

      default:
        throw new Error(`Comando desconocido: ${comando}`);
    }
  } catch (error) {
    console.error('Error en migraciones:', error);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

ejecutar();
