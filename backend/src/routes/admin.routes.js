import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { autorizarRoles } from '../middlewares/authorize.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import { ROLES } from '../constants/roles.js';
import { estadoUsuarioSchema, rolesUsuarioSchema } from '../schemas/admin.schema.js';
import { resumen, usuarios, estadoUsuario, rolesUsuario } from '../controllers/admin.controller.js';

const router = Router();
router.use(verificarToken, autorizarRoles(ROLES.ADMINISTRADOR));
router.get('/resumen', resumen);
router.get('/usuarios', usuarios);
router.patch('/usuarios/:idUsuario/estado', validar(estadoUsuarioSchema), estadoUsuario);
router.put('/usuarios/:idUsuario/roles', validar(rolesUsuarioSchema), rolesUsuario);
export default router;
