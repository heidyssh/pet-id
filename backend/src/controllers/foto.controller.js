import { asyncHandler } from '../utils/asyncHandler.js';
import {
  agregarFotoMascota,
  agregarFotoAvistamiento,
  establecerFotoPrincipalMascota,
  eliminarFotoMascota,
} from '../services/foto.service.js';
import { generarCoincidenciasVisuales } from '../services/coincidencia.service.js';

export const subirFotoMascota = asyncHandler(async (req, res) => {
  const foto = await agregarFotoMascota(
    req.params.idMascota,
    req.usuario.id_usuario,
    req.file,
    req.body.es_principal === 'true',
    req.body.requiere_vector === 'true'
  );
  return res.status(201).json({
    success: true,
    message: 'Fotografía registrada correctamente',
    data: foto,
  });
});

export const marcarFotoPrincipalMascota = asyncHandler(async (req, res) => {
  const foto = await establecerFotoPrincipalMascota(
    req.params.idMascota,
    req.params.idFoto,
    req.usuario.id_usuario
  );
  return res.status(200).json({
    success: true,
    message: 'Foto principal actualizada',
    data: foto,
  });
});

export const borrarFotoMascota = asyncHandler(async (req, res) => {
  const foto = await eliminarFotoMascota(
    req.params.idMascota,
    req.params.idFoto,
    req.usuario.id_usuario
  );
  return res.status(200).json({
    success: true,
    message: 'Fotografía eliminada',
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
  const coincidencias = foto.vector_generado
    ? await generarCoincidenciasVisuales(req.params.idAvistamiento, foto.id_foto)
    : { total: 0, coincidencias: [], procesamiento: 'sin_vector_visual' };
  return res.status(201).json({
    success: true,
    message: 'Fotografía registrada correctamente',
    data: { foto, coincidencias },
  });
});
