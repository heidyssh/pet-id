
import { Router } from 'express';
import rateLimit from 'express-rate-limit';

import {
  registrarAnonimo,
  registrarAutenticado,
  obtenerAvistamientos,
  obtenerMisAvistamientos,
  detalleAvistamiento,
  registrarEscaneoAnonimo,
  registrarEscaneoAutenticado,
} from '../controllers/avistamiento.controller.js';

import {
  crearAvistamientoSchema,
} from '../schemas/avistamiento.schema.js';

import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import { subirFoto } from '../middlewares/upload.middleware.js';
import { subirFotoAvistamiento } from '../controllers/foto.controller.js';
import { buscarAvistamientosCercanos } from '../controllers/geografia.controller.js';
import { limitarConsultasGeograficas } from '../middlewares/geographyLimiter.middleware.js';

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
router.get('/cercanos', limitarConsultasGeograficas, buscarAvistamientosCercanos);

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

router.post(
  '/anonimo-con-foto',
  limiteAvistamientos,
  subirFoto,
  registrarEscaneoAnonimo
);

router.post(
  '/escanear',
  limiteAvistamientos,
  subirFoto,
  registrarEscaneoAnonimo
);

router.post(
  '/escanear/registrado',
  verificarToken,
  limiteAvistamientos,
  subirFoto,
  registrarEscaneoAutenticado
);

// Reportar con sesión iniciada
router.post(
  '/registrado',
  verificarToken,
  limiteAvistamientos,
  validar(crearAvistamientoSchema),
  registrarAutenticado
);

router.post(
  '/:idAvistamiento/fotos',
  verificarToken,
  limiteAvistamientos,
  subirFoto,
  subirFotoAvistamiento
);

// Consultar detalle público
router.get(
  '/:idAvistamiento',
  detalleAvistamiento
);

export default router;
