
import { app } from './app.js';
import { createServer } from 'node:http';
import { Server } from 'socket.io';
import { env } from './config/config.js';
import {
  sequelize,
  verificarConexion,
} from './config/sequelize.js';
import { configurarRealtime } from './services/realtime.service.js';
import { autenticarSocket, conectarSocket } from './services/socket.service.js';

async function iniciarServidor() {
  try {
    await verificarConexion();

    const servidor = createServer(app);
    const io = new Server(servidor, {
      cors: { origin: env.FRONTEND_ORIGIN, methods: ['GET', 'POST'] },
    });
    io.use(autenticarSocket);
    io.on('connection', conectarSocket);
    configurarRealtime(io);

    await new Promise((resolve, reject) => {
      servidor.once('error', reject);
      servidor.listen(env.PORT, resolve);
    });

    console.log('================================');
    console.log('PetID - Backend iniciado');
    console.log(`Entorno: ${env.NODE_ENV}`);
    console.log(`URL: http://localhost:${env.PORT}`);
    console.log('================================');

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
