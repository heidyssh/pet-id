
import express from 'express';
import path from 'node:path';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import sesionRoutes from './routes/sesion.routes.js';
import catalogoRoutes from './routes/catalogo.routes.js';
import mascotaRoutes from './routes/mascota.routes.js';
import { env } from './config/config.js';
import extravioRoutes from './routes/extravio.routes.js';
import avistamientoRoutes from './routes/avistamiento.routes.js';
import coincidenciaRoutes from './routes/coincidencia.routes.js';
import organizacionRoutes from './routes/organizacion.routes.js';
import historialRoutes from './routes/historial.routes.js';
import adopcionRoutes from './routes/adopcion.routes.js';
import notificacionRoutes from './routes/notificacion.routes.js';
import adminRoutes from './routes/admin.routes.js';
import mapaRoutes from './routes/mapa.routes.js';

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

app.use(
  '/storage/imagenes',
  express.static(path.resolve(process.cwd(), 'storage', 'imagenes'), {
    fallthrough: false,
    index: false,
    maxAge: env.NODE_ENV === 'production' ? '1d' : 0,
    setHeaders(res) {
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    },
  })
);

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


// Autenticación
app.use('/api/auth', authRoutes);

// Gestión de sesiones
app.use('/api/sesiones', sesionRoutes);

// Catálogos
app.use('/api/catalogos', catalogoRoutes);

// Mascotas
app.use('/api/mascotas', mascotaRoutes);

//Extravios
app.use('/api/extravios', extravioRoutes);

//Avistamientos
app.use('/api/avistamientos', avistamientoRoutes);
app.use('/api/coincidencias', coincidenciaRoutes);
app.use('/api/organizaciones', organizacionRoutes);
app.use('/api/historial-clinico', historialRoutes);
app.use('/api/adopciones', adopcionRoutes);
app.use('/api/notificaciones', notificacionRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/mapas', mapaRoutes);


// ==========================================
// RUTA NO ENCONTRADA
// ==========================================

app.use(notFoundMiddleware);

// ==========================================
// MANEJO GLOBAL DE ERRORES
// ==========================================

app.use(errorMiddleware);
