import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { listar, leer } from '../controllers/notificacion.controller.js';
import {
  actualizarUbicacion,
  desactivarUbicacion,
  consultarUbicacion,
  registrarDispositivo,
  eliminarDispositivo,
} from '../controllers/notificacion.controller.js';
import { validar } from '../middlewares/validate.middleware.js';
import { actualizarAlertaUbicacionSchema } from '../schemas/alertaUbicacion.schema.js';
import {
  registrarDispositivoPushSchema,
  eliminarDispositivoPushSchema,
} from '../schemas/dispositivoPush.schema.js';

const router = Router();
router.use(verificarToken);
router.get('/', listar);
router.get('/ubicacion-alertas', consultarUbicacion);
router.put('/ubicacion-alertas', validar(actualizarAlertaUbicacionSchema), actualizarUbicacion);
router.delete('/ubicacion-alertas', desactivarUbicacion);
router.post('/dispositivos', validar(registrarDispositivoPushSchema), registrarDispositivo);
router.delete('/dispositivos', validar(eliminarDispositivoPushSchema), eliminarDispositivo);
router.patch('/:idNotificacion/leer', leer);
export default router;
