
import { Router } from 'express';

import {
  registro,
  login,
  loginGoogle,
  me,
  actualizarMe,
  actualizarMiFoto,
  eliminarMiFoto,
} from '../controllers/auth.controller.js';

import {
  registroSchema,
  loginSchema,
  loginGoogleSchema,
  actualizarPerfilSchema,
} from '../schemas/auth.schema.js';

import {
  reenviarVerificacion,
  confirmarCorreo,
  solicitarCambioPassword,
  confirmarCambioPassword,
} from '../controllers/auth.controller.js';

import {
  solicitudCorreoSchema,
  confirmarTokenSchema,
  restablecerPasswordSchema,
} from '../schemas/auth.schema.js';

import { validar } from '../middlewares/validate.middleware.js';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { subirFoto } from '../middlewares/upload.middleware.js';

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

router.post('/google', loginLimiter, validar(loginGoogleSchema), loginGoogle);

router.get(
  '/me',
  verificarToken,
  me
);

router.patch(
  '/me',
  verificarToken,
  validar(actualizarPerfilSchema),
  actualizarMe
);

router.put('/me/foto', verificarToken, subirFoto, actualizarMiFoto);
router.delete('/me/foto', verificarToken, eliminarMiFoto);

router.post(
  '/reenviar-verificacion',
  registroLimiter,
  validar(solicitudCorreoSchema),
  reenviarVerificacion
);

router.post(
  '/verificar-correo',
  registroLimiter,
  validar(confirmarTokenSchema),
  confirmarCorreo
);

router.post(
  '/recuperar-contrasena',
  registroLimiter,
  validar(solicitudCorreoSchema),
  solicitarCambioPassword
);

router.post(
  '/restablecer-contrasena',
  registroLimiter,
  validar(restablecerPasswordSchema),
  confirmarCambioPassword
);

export default router;
