import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import { revisarCoincidenciaSchema } from '../schemas/coincidencia.schema.js';
import { listarPorReporte, revisar } from '../controllers/coincidencia.controller.js';

const router = Router();
router.use(verificarToken);
router.get('/reportes/:idReporte', listarPorReporte);
router.patch('/:idCoincidencia/revision', validar(revisarCoincidenciaSchema), revisar);
export default router;
