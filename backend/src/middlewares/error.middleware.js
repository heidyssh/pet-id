
import { AppError } from '../utils/AppError.js';

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
