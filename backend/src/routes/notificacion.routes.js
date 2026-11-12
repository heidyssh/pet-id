import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { listar, leer } from '../controllers/notificacion.controller.js';

const router = Router();
router.use(verificarToken);
router.get('/', listar);
router.patch('/:idNotificacion/leer', leer);
export default router;
