
import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';

import {
  renovar,
  misSesiones,
  cerrarActual,
  cerrarDispositivo,
  cerrarTodas,
} from '../controllers/sesion.controller.js';

import {
  renovarSesionSchema,
  idSesionSchema,
} from '../schemas/sesion.schema.js';

import { validar } from '../middlewares/validate.middleware.js';
import { verificarToken } from '../middlewares/auth.middleware.js';

const router = Router();

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Demasiadas solicitudes de renovación',
  },
});

// Renovación: usa refresh token, no access token.
router.post(
  '/renovar',
  refreshLimiter,
  validar(renovarSesionSchema),
  renovar
);

// Las demás rutas necesitan un JWT válido.
router.use(verificarToken);

// Consultar dispositivos conectados.
router.get('/', misSesiones);

// Cerrar la sesión actual.
router.post('/cerrar', cerrarActual);

// Cerrar todas las sesiones.
router.post('/cerrar-todas', cerrarTodas);

// Cerrar una sesión específica.
router.delete(
  '/:idSesion',
  (req, res, next) => {
    const resultado = idSesionSchema.safeParse(req.params);

    if (!resultado.success) {
      return res.status(400).json({
        success: false,
        message: 'Identificador de sesión inválido',
      });
    }

    next();
  },
  cerrarDispositivo
);

export default router;
