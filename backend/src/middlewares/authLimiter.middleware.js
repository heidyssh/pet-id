
import { rateLimit } from 'express-rate-limit';

const respuesta = {
  success: false,
  message: 'Demasiados intentos. Intentá nuevamente más tarde.',
};

export const registroLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: respuesta,
});

export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: respuesta,
});
