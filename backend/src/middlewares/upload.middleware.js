
import multer from 'multer';
import { AppError } from '../utils/AppError.js';

const MIME_PERMITIDOS = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

export const subirFoto = multer({
  storage: multer.memoryStorage(),

  limits: {
    fileSize: 5 * 1024 * 1024,
    files: 1,
    fields: 5,
    parts: 6,
  },

  fileFilter(req, file, callback) {
    if (!MIME_PERMITIDOS.has(file.mimetype)) {
      return callback(
        new AppError(
          'Solo se permiten imágenes JPG, PNG o WebP',
          400
        )
      );
    }

    return callback(null, true);
  },
}).single('foto');
