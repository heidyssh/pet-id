
import { Router } from 'express';

import {
  registrarMascota,
  misMascotas,
  detalleMascota,
  editarMascota,
} from '../controllers/mascota.controller.js';

import {
  crearMascotaSchema,
  actualizarMascotaSchema,
} from '../schemas/mascota.schema.js';

import { validar } from '../middlewares/validate.middleware.js';
import { verificarToken } from '../middlewares/auth.middleware.js';

const router = Router();

// Todas estas rutas requieren una sesión válida.
router.use(verificarToken);

// Registrar mascota
router.post(
  '/',
  validar(crearMascotaSchema),
  registrarMascota
);

// Listar mascotas del usuario
router.get(
  '/mias',
  misMascotas
);

// Consultar una mascota propia
router.get(
  '/:idMascota',
  detalleMascota
);

// Editar una mascota propia
router.patch(
  '/:idMascota',
  validar(actualizarMascotaSchema),
  editarMascota
);

export default router;
