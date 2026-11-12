import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { autorizarOrganizacion } from '../middlewares/organization.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import { crearHistorialSchema, actualizarHistorialSchema } from '../schemas/historial.schema.js';
import { crear, listarPropio, actualizar } from '../controllers/historial.controller.js';

const router = Router();
router.use(verificarToken);
router.get('/mascotas/:idMascota', listarPropio);
router.post('/organizaciones/:idOrganizacion/mascotas/:idMascota', autorizarOrganizacion(), validar(crearHistorialSchema), crear);
router.patch('/organizaciones/:idOrganizacion/:idHistorial', autorizarOrganizacion(), validar(actualizarHistorialSchema), actualizar);
export default router;
