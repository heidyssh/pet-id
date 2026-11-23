import rateLimit from 'express-rate-limit';

import { env } from '../config/config.js';

export const limitarConsultasGeograficas = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skip: () => env.NODE_ENV === 'test',
  message: {
    success: false,
    message: 'Demasiadas consultas de ubicación. Intenta nuevamente en unos minutos.',
  },
});
