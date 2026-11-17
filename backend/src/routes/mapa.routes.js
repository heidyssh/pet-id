import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import {
  geocodificar,
  reversa,
  configuracion,
} from '../controllers/mapa.controller.js';

const router = Router();
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { success: false, message: 'Demasiadas consultas de ubicación' },
});

router.get('/geocodificar', limiter, geocodificar);
router.get('/geocodificar-reversa', limiter, reversa);
router.get('/configuracion', configuracion);
export default router;
