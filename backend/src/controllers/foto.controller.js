import { asyncHandler } from '../utils/asyncHandler.js';
import {
  agregarFotoMascota,
  agregarFotoAvistamiento,
} from '../services/foto.service.js';

export const subirFotoMascota = asyncHandler(async (req, res) => {
  const foto = await agregarFotoMascota(
    req.params.idMascota,
    req.usuario.id_usuario,
    req.file,
    req.body.es_principal === 'true'
  );
  return res.status(201).json({
    success: true,
    message: 'Fotografía registrada correctamente',
    data: foto,
  });
});

export const subirFotoAvistamiento = asyncHandler(async (req, res) => {
  const foto = await agregarFotoAvistamiento(
    req.params.idAvistamiento,
    req.usuario.id_usuario,
    req.file,
    req.body.tipo_captura
  );
  return res.status(201).json({
    success: true,
    message: 'Fotografía registrada correctamente',
    data: foto,
  });
});
