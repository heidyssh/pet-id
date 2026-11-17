
import { Usuario } from './Usuario.js';
import { Rol } from './Rol.js';
import { UsuarioRol } from './UsuarioRol.js';
import { Organizacion } from './Organizacion.js';
import { UsuarioOrganizacion } from './UsuarioOrganizacion.js';
import { Especie } from './Especie.js';
import { Raza } from './Raza.js';
import { Mascota } from './Mascota.js';
import { FotoMascota } from './FotoMascota.js';
import { ReporteExtravio } from './ReporteExtravio.js';
import { Avistamiento } from './Avistamiento.js';
import { FotoAvistamiento } from './FotoAvistamiento.js';
import { Coincidencia } from './Coincidencia.js';
import { HistorialClinico } from './HistorialClinico.js';
import { PublicacionAdopcion } from './PublicacionAdopcion.js';
import { SolicitudAdopcion } from './SolicitudAdopcion.js';
import { TokenSeguridad } from './TokenSeguridad.js';
import { SesionUsuario } from './SesionUsuario.js';
import { RefreshTokenUsado } from './RefreshTokenUsado.js';
import { Notificacion } from './Notificacion.js';
import { VectorVisual } from './VectorVisual.js';
import { SuscripcionUbicacion } from './SuscripcionUbicacion.js';
import { AlertaExtravioEnviada } from './AlertaExtravioEnviada.js';
import { DispositivoPush } from './DispositivoPush.js';

// ==========================================
// USUARIOS Y ROLES (N:M)
// ==========================================

Usuario.belongsToMany(Rol, {
  through: UsuarioRol,
  foreignKey: 'id_usuario',
  otherKey: 'id_rol',
  as: 'roles',
});

Rol.belongsToMany(Usuario, {
  through: UsuarioRol,
  foreignKey: 'id_rol',
  otherKey: 'id_usuario',
  as: 'usuarios',
});

UsuarioRol.belongsTo(Rol, {
  foreignKey: 'id_rol',
  as: 'rol',
});

UsuarioRol.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});

// ==========================================
// USUARIOS Y ORGANIZACIONES (N:M)
// ==========================================

Usuario.belongsToMany(Organizacion, {
  through: UsuarioOrganizacion,
  foreignKey: 'id_usuario',
  otherKey: 'id_organizacion',
  as: 'organizaciones',
});

Organizacion.belongsToMany(Usuario, {
  through: UsuarioOrganizacion,
  foreignKey: 'id_organizacion',
  otherKey: 'id_usuario',
  as: 'miembros',
});

// ==========================================
// ESPECIES Y RAZAS (1:N)
// ==========================================

Especie.hasMany(Raza, {
  foreignKey: 'id_especie',
  as: 'razas',
});

Raza.belongsTo(Especie, {
  foreignKey: 'id_especie',
  as: 'especie',
});

// ==========================================
// USUARIOS Y MASCOTAS (1:N)
// ==========================================

Usuario.hasMany(Mascota, {
  foreignKey: 'id_dueno',
  as: 'mascotas',
});

Mascota.belongsTo(Usuario, {
  foreignKey: 'id_dueno',
  as: 'dueno',
});

// ==========================================
// ESPECIES, RAZAS Y MASCOTAS
// ==========================================

Especie.hasMany(Mascota, {
  foreignKey: 'id_especie',
  as: 'mascotas',
});

Mascota.belongsTo(Especie, {
  foreignKey: 'id_especie',
  as: 'especie',
});

Raza.hasMany(Mascota, {
  foreignKey: 'id_raza',
  as: 'mascotas',
  constraints: false,
});

Mascota.belongsTo(Raza, {
  foreignKey: 'id_raza',
  as: 'raza',
  constraints: false,
});

// La FK compuesta de raza y especie
// se controla en PostgreSQL.

// ==========================================
// MASCOTAS Y FOTOGRAFÍAS (1:N)
// ==========================================

Mascota.hasMany(FotoMascota, {
  foreignKey: 'id_mascota',
  as: 'fotos',
});

FotoMascota.belongsTo(Mascota, {
  foreignKey: 'id_mascota',
  as: 'mascota',
});

FotoMascota.hasOne(VectorVisual, {
  foreignKey: 'id_foto_mascota',
  as: 'vectorVisual',
});

VectorVisual.belongsTo(FotoMascota, {
  foreignKey: 'id_foto_mascota',
  as: 'fotoMascota',
});

// ==========================================
// MASCOTAS Y REPORTES DE EXTRAVÍO (1:N)
// ==========================================

Mascota.hasMany(ReporteExtravio, {
  foreignKey: 'id_mascota',
  as: 'reportesExtravio',
});

ReporteExtravio.belongsTo(Mascota, {
  foreignKey: 'id_mascota',
  as: 'mascota',
});

// ==========================================
// USUARIOS Y AVISTAMIENTOS (1:N)
// ==========================================

Usuario.hasMany(Avistamiento, {
  foreignKey: 'id_usuario',
  as: 'avistamientos',
});

Avistamiento.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});

// ==========================================
// ESPECIES Y AVISTAMIENTOS (1:N)
// ==========================================

Especie.hasMany(Avistamiento, {
  foreignKey: 'id_especie',
  as: 'avistamientos',
});

Avistamiento.belongsTo(Especie, {
  foreignKey: 'id_especie',
  as: 'especie',
});

// ==========================================
// AVISTAMIENTOS Y FOTOGRAFÍAS (1:N)
// ==========================================

Avistamiento.hasMany(FotoAvistamiento, {
  foreignKey: 'id_avistamiento',
  as: 'fotos',
});

FotoAvistamiento.belongsTo(Avistamiento, {
  foreignKey: 'id_avistamiento',
  as: 'avistamiento',
});

FotoAvistamiento.hasOne(VectorVisual, {
  foreignKey: 'id_foto_avistamiento',
  as: 'vectorVisual',
});

VectorVisual.belongsTo(FotoAvistamiento, {
  foreignKey: 'id_foto_avistamiento',
  as: 'fotoAvistamiento',
});

// ==========================================
// AVISTAMIENTOS Y COINCIDENCIAS (1:N)
// ==========================================

Avistamiento.hasMany(Coincidencia, {
  foreignKey: 'id_avistamiento',
  as: 'coincidencias',
});

Coincidencia.belongsTo(Avistamiento, {
  foreignKey: 'id_avistamiento',
  as: 'avistamiento',
});

// ==========================================
// REPORTES Y COINCIDENCIAS (1:N)
// ==========================================

ReporteExtravio.hasMany(Coincidencia, {
  foreignKey: 'id_reporte',
  as: 'coincidencias',
});

Coincidencia.belongsTo(ReporteExtravio, {
  foreignKey: 'id_reporte',
  as: 'reporte',
});

// ==========================================
// MASCOTAS E HISTORIAL CLÍNICO (1:N)
// ==========================================

Mascota.hasMany(HistorialClinico, {
  foreignKey: 'id_mascota',
  as: 'historialClinico',
});

HistorialClinico.belongsTo(Mascota, {
  foreignKey: 'id_mascota',
  as: 'mascota',
});

// ==========================================
// ORGANIZACIONES E HISTORIAL CLÍNICO
// ==========================================

Organizacion.hasMany(HistorialClinico, {
  foreignKey: 'id_organizacion',
  as: 'atenciones',
});

HistorialClinico.belongsTo(Organizacion, {
  foreignKey: 'id_organizacion',
  as: 'organizacion',
});

// ==========================================
// USUARIO RESPONSABLE DEL REGISTRO CLÍNICO
// ==========================================

Usuario.hasMany(HistorialClinico, {
  foreignKey: 'id_usuario_registro',
  as: 'registrosClinicos',
});

HistorialClinico.belongsTo(Usuario, {
  foreignKey: 'id_usuario_registro',
  as: 'registradoPor',
});

// ==========================================
// MASCOTAS Y PUBLICACIONES DE ADOPCIÓN
// ==========================================

Mascota.hasMany(PublicacionAdopcion, {
  foreignKey: 'id_mascota',
  as: 'publicacionesAdopcion',
});

PublicacionAdopcion.belongsTo(Mascota, {
  foreignKey: 'id_mascota',
  as: 'mascota',
});

// ==========================================
// ORGANIZACIONES Y ADOPCIONES
// ==========================================

Organizacion.hasMany(PublicacionAdopcion, {
  foreignKey: 'id_organizacion',
  as: 'publicacionesAdopcion',
});

PublicacionAdopcion.belongsTo(Organizacion, {
  foreignKey: 'id_organizacion',
  as: 'organizacion',
});

// ==========================================
// PUBLICACIONES Y SOLICITUDES (1:N)
// ==========================================

PublicacionAdopcion.hasMany(SolicitudAdopcion, {
  foreignKey: 'id_publicacion',
  as: 'solicitudes',
});

SolicitudAdopcion.belongsTo(PublicacionAdopcion, {
  foreignKey: 'id_publicacion',
  as: 'publicacion',
});

// ==========================================
// USUARIOS Y SOLICITUDES DE ADOPCIÓN
// ==========================================

Usuario.hasMany(SolicitudAdopcion, {
  foreignKey: 'id_usuario',
  as: 'solicitudesAdopcion',
});

SolicitudAdopcion.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'solicitante',
});

Usuario.hasMany(TokenSeguridad, {
  foreignKey: 'id_usuario',
  as: 'tokensSeguridad',
});

TokenSeguridad.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});
// =====================================
// USUARIOS Y SESIONES
// =====================================

Usuario.hasMany(SesionUsuario, {
  foreignKey: 'id_usuario',
  as: 'sesiones',
});

SesionUsuario.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});

// =====================================
// SESIONES Y TOKENS UTILIZADOS
// =====================================

SesionUsuario.hasMany(RefreshTokenUsado, {
  foreignKey: 'id_sesion',
  as: 'tokensUsados',
});

RefreshTokenUsado.belongsTo(SesionUsuario, {
  foreignKey: 'id_sesion',
  as: 'sesion',
});

Usuario.hasMany(Notificacion, {
  foreignKey: 'id_usuario',
  as: 'notificaciones',
});

Notificacion.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});

Usuario.hasOne(SuscripcionUbicacion, {
  foreignKey: 'id_usuario',
  as: 'suscripcionUbicacion',
});

SuscripcionUbicacion.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});

Usuario.hasMany(AlertaExtravioEnviada, {
  foreignKey: 'id_usuario',
  as: 'alertasExtravioEnviadas',
});

ReporteExtravio.hasMany(AlertaExtravioEnviada, {
  foreignKey: 'id_reporte',
  as: 'alertasEnviadas',
});

Usuario.hasMany(DispositivoPush, {
  foreignKey: 'id_usuario',
  as: 'dispositivosPush',
});

DispositivoPush.belongsTo(Usuario, {
  foreignKey: 'id_usuario',
  as: 'usuario',
});


  // ==========================================
  // EXPORTACIONES
  // ==========================================

  export {
    Usuario,
    Rol,
    UsuarioRol,
    Organizacion,
    UsuarioOrganizacion,
    Especie,
    Raza,
    Mascota,
    FotoMascota,
    ReporteExtravio,
    Avistamiento,
    FotoAvistamiento,
    Coincidencia,
    HistorialClinico,
    PublicacionAdopcion,
    SolicitudAdopcion,
    TokenSeguridad,
    SesionUsuario,
    RefreshTokenUsado,
    Notificacion,
    VectorVisual,
    SuscripcionUbicacion,
    AlertaExtravioEnviada,
    DispositivoPush,
  };
