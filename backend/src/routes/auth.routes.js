
import { Router } from 'express';

import {
  registro,
  login,
  me,
} from '../controllers/auth.controller.js';

import {
  registroSchema,
  loginSchema,
} from '../schemas/auth.schema.js';

import { validar } from '../middlewares/validate.middleware.js';
import { verificarToken } from '../middlewares/auth.middleware.js';

import {
  registroLimiter,
  loginLimiter,
} from '../middlewares/authLimiter.middleware.js';

const router = Router();

router.post(
  '/registro',
  registroLimiter,
  validar(registroSchema),
  registro
);

router.post(
  '/login',
  loginLimiter,
  validar(loginSchema),
  login
);

router.get(
  '/me',
  verificarToken,
  me
);

export default router;
