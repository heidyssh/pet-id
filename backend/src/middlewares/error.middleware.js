
import { AppError } from '../utils/AppError.js';
import multer from 'multer';

export function errorMiddleware(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      console.error('Error interno:', err);
    }

    return res.status(err.statusCode).json({
      success: false,
      message: err.statusCode >= 500
        ? 'Error interno del servidor'
        : err.message,
    });
  }

  if (err.type === 'entity.too.large') {
    return res.status(413).json({
      success: false,
      message: 'La solicitud excede el tamaño permitido',
    });
  }

  if (err instanceof multer.MulterError) {
    return res.status(err.code === 'LIMIT_FILE_SIZE' ? 413 : 400).json({
      success: false,
      message: err.code === 'LIMIT_FILE_SIZE'
        ? 'La imagen excede el tamaño permitido'
        : 'No se pudo procesar el archivo enviado',
    });
  }

  if (err.name === 'SequelizeValidationError') {
    return res.status(400).json({
      success: false,
      message: 'Los datos no cumplen las restricciones requeridas',
    });
  }

  if (err.name === 'SequelizeUniqueConstraintError') {
    return res.status(409).json({
      success: false,
      message: 'El registro ya existe',
    });
  }

  if (err instanceof SyntaxError && err.status === 400) {
    return res.status(400).json({
      success: false,
      message: 'El JSON enviado no es válido',
    });
  }

  console.error('Error inesperado:', err);

  return res.status(500).json({
    success: false,
    message: 'Error interno del servidor',
  });
}
