
import { Router } from 'express';

import {
  registrarExtravio,
  obtenerExtravios,
  obtenerMisExtravios,
  detalleExtravio,
  marcarExtravioResuelto,
} from '../controllers/extravio.controller.js';

import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';

import {
  crearExtravioSchema,
} from '../schemas/extravio.schema.js';
import { buscarExtraviosCercanos } from '../controllers/geografia.controller.js';
import { limitarConsultasGeograficas } from '../middlewares/geographyLimiter.middleware.js';

const router = Router();

// Consultar reportes activos
router.get('/', obtenerExtravios);
router.get('/cercanos', limitarConsultasGeograficas, buscarExtraviosCercanos);

// Consultar reportes propios
router.get(
  '/mios',
  verificarToken,
  obtenerMisExtravios
);

// Registrar extravío
router.post(
  '/',
  verificarToken,
  validar(crearExtravioSchema),
  registrarExtravio
);

// Resolver extravío propio
router.patch(
  '/:idReporte/resolver',
  verificarToken,
  marcarExtravioResuelto
);

// Consultar detalle público
router.get('/:idReporte', detalleExtravio);

export default router;
