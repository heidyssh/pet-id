
import { sequelize } from '../src/config/sequelize.js';
import * as modelos from '../src/models/index.js';

async function probarModelos() {
  try {
    await sequelize.authenticate();

    console.log('\n=== PETID - PRUEBA DE MODELOS ===\n');

    for (const [nombre, modelo] of Object.entries(modelos)) {
      const cantidad = await modelo.count();

      console.log(
        `${nombre}: ${cantidad} registros - OK`
      );
    }

    // Verificar una relación existente
    const especies = await modelos.Especie.findAll({
      attributes: ['nombre'],
      include: [{
        model: modelos.Raza,
        as: 'razas',
        attributes: ['nombre'],
      }],
    });

    console.log('\n=== RELACIONES ===');

    for (const especie of especies) {
      console.log(
        `${especie.nombre}: ${especie.razas.length} razas`
      );
    }

    console.log('\n16 modelos consultados correctamente');

  } catch (error) {
    console.error('\nError:', error);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

probarModelos();
