
import { Router } from 'express';

import {
  obtenerEspecies,
  obtenerRazas,
} from '../controllers/catalogo.controller.js';

const router = Router();

// Catálogos de consulta pública
router.get('/especies', obtenerEspecies);
router.get('/razas', obtenerRazas);

export default router;
