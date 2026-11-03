
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

import { env } from './config/config.js';

import authRoutes from './routes/auth.routes.js';

import {
  notFoundMiddleware,
} from './middlewares/notFound.middleware.js';

import {
  errorMiddleware,
} from './middlewares/error.middleware.js';

// ==========================================
// INICIALIZACIÓN DE EXPRESS
// ==========================================

export const app = express();

// ==========================================
// SEGURIDAD HTTP
// ==========================================

// Protección de cabeceras HTTP
app.disable('x-powered-by');
app.use(helmet());

// ==========================================
// CORS
// ==========================================

// Permitir únicamente el frontend autorizado
app.use(cors({
  origin: env.FRONTEND_ORIGIN,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: false,
}));

// ==========================================
// LÍMITES DE SOLICITUDES
// ==========================================

app.use(rateLimit({
  windowMs: 60 * 1000,
  limit: 300,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skip: (req) =>
    req.path === '/api/health' ||
    env.NODE_ENV === 'test',
}));

// ==========================================
// PROCESAMIENTO DE DATOS
// ==========================================

// Limitar el tamaño de las solicitudes JSON
app.use(express.json({
  limit: '16kb',
}));

// ==========================================
// HEALTH CHECK
// ==========================================

app.get('/api/health', (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'API PetID funcionando correctamente',
  });
});

// ==========================================
// RUTAS DE LA API
// ==========================================

// Autenticación y usuarios
app.use('/api/auth', authRoutes);

// Próximos módulos:
// app.use('/api/usuarios', usuarioRoutes);
// app.use('/api/mascotas', mascotaRoutes);
// app.use('/api/extravios', reporteExtravioRoutes);
// app.use('/api/avistamientos', avistamientoRoutes);
// app.use('/api/organizaciones', organizacionRoutes);
// app.use('/api/adopciones', adopcionRoutes);

// ==========================================
// RUTA NO ENCONTRADA
// ==========================================

app.use(notFoundMiddleware);

// ==========================================
// MANEJO GLOBAL DE ERRORES
// ==========================================

app.use(errorMiddleware);
