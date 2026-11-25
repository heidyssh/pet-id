import { asyncHandler } from '../utils/asyncHandler.js';
import {
  agregarFotoMascota,
  agregarFotoAvistamiento,
} from '../services/foto.service.js';
import { asignarEspecieDetectada } from '../services/avistamiento.service.js';
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

export const subirFotoAvistamiento = asyncHandler(async (req, res) => {
  const foto = await agregarFotoAvistamiento(
    req.params.idAvistamiento,
    req.usuario.id_usuario,
    req.file,
    req.body.tipo_captura
  );
  if (foto.deteccion) {
    await asignarEspecieDetectada(
      req.params.idAvistamiento,
      foto.deteccion.etiqueta
    );
  }
  const coincidencias = foto.vector_generado
    ? await generarCoincidenciasVisuales(req.params.idAvistamiento, foto.id_foto)
    : { total: 0, coincidencias: [], procesamiento: 'sin_vector_visual' };
  return res.status(201).json({
    success: true,
    message: 'Fotografía registrada correctamente',
    data: { foto, coincidencias },
  });
});
