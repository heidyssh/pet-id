import { asyncHandler } from '../utils/asyncHandler.js';
import {
  listarCoincidenciasReporte,
  revisarCoincidencia,
  buscarMascotasSimilares,
} from '../services/coincidencia.service.js';

export const buscarVisuales = asyncHandler(async (req, res) => {
  const data = await buscarMascotasSimilares(req.file, 5, req.usuario.id_usuario);
  return res.status(200).json({ success: true, data });
});

export const listarPorReporte = asyncHandler(async (req, res) => {
  const items = await listarCoincidenciasReporte(
    req.params.idReporte,
    req.usuario.id_usuario
  );
  return res.status(200).json({
    success: true,
    data: { items, aviso: 'La puntuación indica compatibilidad de reglas, no identidad confirmada.' },
  });
});

export const revisar = asyncHandler(async (req, res) => {
  const data = await revisarCoincidencia(
    req.params.idCoincidencia,
    req.usuario.id_usuario,
    req.body.estado_revision
  );
  return res.status(200).json({
    success: true,
    message: 'Coincidencia revisada correctamente',
    data,
  });
});
