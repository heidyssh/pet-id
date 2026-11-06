
import { Router } from 'express';
import rateLimit from 'express-rate-limit';

import {
  registrarAnonimo,
  registrarAutenticado,
  obtenerAvistamientos,
  obtenerMisAvistamientos,
  detalleAvistamiento,
} from '../controllers/avistamiento.controller.js';

import {
  crearAvistamientoSchema,
} from '../schemas/avistamiento.schema.js';

import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';

const router = Router();

const limiteAvistamientos = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Demasiados reportes. Intentá más tarde.',
  },
});

// Consultas públicas
router.get('/', obtenerAvistamientos);

// Reportes del usuario autenticado
router.get(
  '/mios',
  verificarToken,
  obtenerMisAvistamientos
);

// Reportar sin iniciar sesión
router.post(
  '/',
  limiteAvistamientos,
  validar(crearAvistamientoSchema),
  registrarAnonimo
);

// Reportar con sesión iniciada
router.post(
  '/registrado',
  verificarToken,
  limiteAvistamientos,
  validar(crearAvistamientoSchema),
  registrarAutenticado
);

// Consultar detalle público
router.get(
  '/:idAvistamiento',
  detalleAvistamiento
);

export default router;
