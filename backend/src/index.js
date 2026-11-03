
import { app } from './app.js';
import { env } from './config/config.js';
import {
  sequelize,
  verificarConexion,
} from './config/sequelize.js';

async function iniciarServidor() {
  try {
    await verificarConexion();

    const servidor = app.listen(env.PORT, () => {
      console.log('================================');
      console.log('PetID - Backend iniciado');
      console.log(`Entorno: ${env.NODE_ENV}`);
      console.log(`URL: http://localhost:${env.PORT}`);
      console.log('================================');
    });

    async function cerrarServidor() {
      servidor.close(async () => {
        await sequelize.close();
        process.exit(0);
      });
    }

    process.on('SIGINT', cerrarServidor);
    process.on('SIGTERM', cerrarServidor);

  } catch (error) {
    console.error('Error al iniciar PetID:', error.message);
    await sequelize.close();
    process.exit(1);
  }
}

iniciarServidor();
