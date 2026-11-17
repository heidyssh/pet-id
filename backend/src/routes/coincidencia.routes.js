import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import { revisarCoincidenciaSchema } from '../schemas/coincidencia.schema.js';
import {
  listarPorReporte,
  revisar,
  buscarVisuales,
} from '../controllers/coincidencia.controller.js';
import { subirFoto } from '../middlewares/upload.middleware.js';

const router = Router();
router.use(verificarToken);
router.post('/visuales/buscar', subirFoto, buscarVisuales);
router.get('/reportes/:idReporte', listarPorReporte);
router.patch('/:idCoincidencia/revision', validar(revisarCoincidenciaSchema), revisar);
export default router;
