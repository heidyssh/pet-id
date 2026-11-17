import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import { autorizarOrganizacion } from '../middlewares/organization.middleware.js';
import { autorizarRoles } from '../middlewares/authorize.middleware.js';
import { ROLES } from '../constants/roles.js';
import {
  crearOrganizacionSchema,
  actualizarOrganizacionSchema,
  membresiaSchema,
  verificarOrganizacionSchema,
} from '../schemas/organizacion.schema.js';
import {
  registrar, listar, actualizar, guardarMiembro, miembros, cambiarVerificacion,
} from '../controllers/organizacion.controller.js';

const router = Router();
router.get('/', listar);
router.post('/', verificarToken, validar(crearOrganizacionSchema), registrar);
router.patch('/:idOrganizacion/verificacion', verificarToken, autorizarRoles(ROLES.ADMINISTRADOR), validar(verificarOrganizacionSchema), cambiarVerificacion);
router.patch('/:idOrganizacion', verificarToken, autorizarOrganizacion({ cargosPermitidos: ['administrador'] }), validar(actualizarOrganizacionSchema), actualizar);
router.get('/:idOrganizacion/miembros', verificarToken, autorizarOrganizacion({ cargosPermitidos: ['administrador'] }), miembros);
router.put('/:idOrganizacion/miembros', verificarToken, autorizarOrganizacion({ cargosPermitidos: ['administrador'] }), validar(membresiaSchema), guardarMiembro);
export default router;
