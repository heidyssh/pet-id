import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware.js';
import { validar } from '../middlewares/validate.middleware.js';
import * as esquema from '../schemas/adopcion.schema.js';
import * as controlador from '../controllers/adopcion.controller.js';

const router = Router();
router.get('/publicaciones', controlador.listarPublicaciones);
router.get('/publicaciones/:idPublicacion', controlador.detalle);
router.post('/publicaciones', verificarToken, validar(esquema.crearPublicacionSchema), controlador.crearPublicacion);
router.patch('/publicaciones/:idPublicacion/cerrar', verificarToken, validar(esquema.cerrarPublicacionSchema), controlador.cerrar);
router.post('/publicaciones/:idPublicacion/solicitudes', verificarToken, validar(esquema.crearSolicitudSchema), controlador.solicitar);
router.get('/publicaciones/:idPublicacion/solicitudes', verificarToken, controlador.solicitudes);
router.get('/solicitudes/mias', verificarToken, controlador.mias);
router.patch('/solicitudes/:idSolicitud/revision', verificarToken, validar(esquema.revisarSolicitudSchema), controlador.revisar);
router.patch('/solicitudes/:idSolicitud/cancelar', verificarToken, controlador.cancelar);
export default router;
