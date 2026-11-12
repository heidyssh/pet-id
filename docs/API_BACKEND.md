# PetID — contrato inicial del backend

Base local: `http://localhost:3000/api`

Las respuestas exitosas usan `{ "success": true, "data": ... }`; los errores usan
`{ "success": false, "message": "..." }`. Las rutas privadas reciben
`Authorization: Bearer <access_token>`. Las fechas con hora son ISO 8601 y las
fechas clínicas son `YYYY-MM-DD`.

## Autenticación y sesiones

- `POST /auth/registro` — crea un ciudadano.
- `POST /auth/login` — devuelve `usuario`, `access_token`, `refresh_token`,
  `token_type` y `expires_in`.
- `GET /auth/me` — perfil y roles.
- `POST /auth/reenviar-verificacion`, `/auth/verificar-correo`,
  `/auth/recuperar-contrasena`, `/auth/restablecer-contrasena`.
- `POST /sesiones/renovar` — rota el refresh token.
- `GET /sesiones`, `POST /sesiones/cerrar`, `POST /sesiones/cerrar-todas`,
  `DELETE /sesiones/:idSesion`.

## Catálogos, mascotas y fotografías

- `GET /catalogos/especies`, `GET /catalogos/razas?id_especie=1`.
- `POST /mascotas`, `GET /mascotas/mias`, `GET|PATCH /mascotas/:idMascota`.
- `POST /mascotas/:idMascota/fotos` — `multipart/form-data`, archivo `foto`,
  campo opcional `es_principal=true`.

## Extravíos, avistamientos y mapas

- `GET|POST /extravios`, `GET /extravios/mios`,
  `GET /extravios/:idReporte`, `PATCH /extravios/:idReporte/resolver`.
- `GET|POST /avistamientos`, `POST /avistamientos/registrado`,
  `GET /avistamientos/mios`, `GET /avistamientos/:idAvistamiento`.
- `POST /avistamientos/anonimo-con-foto` — `multipart/form-data` con archivo
  `foto`, JSON del reporte en `datos` y `tipo_captura` opcional; crea ambos en
  una sola operación y no concede permisos posteriores sobre el identificador.
- `POST /avistamientos/:idAvistamiento/fotos` — privado para el autor;
  `multipart/form-data` con `foto` y `tipo_captura`.
- `GET /extravios/cercanos` y `GET /avistamientos/cercanos` — parámetros
  `latitud`, `longitud`, `radio_km`, `id_especie`, `pagina`, `limite`.
  Las coordenadas públicas se redondean a tres decimales.
- `GET /mapas/geocodificar?direccion=...` — búsqueda de direcciones restringida
  a Honduras mediante el backend.
- `GET /mapas/geocodificar-reversa?latitud=...&longitud=...` — convierte un
  punto seleccionado/GPS en una referencia legible.

## Coincidencias

- `GET /coincidencias/reportes/:idReporte` — propietario del reporte.
- `PATCH /coincidencias/:idCoincidencia/revision` con
  `{ "estado_revision": "confirmada|descartada" }`.

La puntuación es compatibilidad de reglas descriptivas/geográficas, no una
probabilidad de identidad.

## Organizaciones e historial clínico

- `GET|POST /organizaciones`.
- `PATCH /organizaciones/:idOrganizacion`.
- `GET|PUT /organizaciones/:idOrganizacion/miembros`.
- `PATCH /organizaciones/:idOrganizacion/verificacion` — administrador.
- `GET /historial-clinico/mascotas/:idMascota` — propietario; devuelve una
  instantánea con `sincronizado_en` apta para caché offline.
- `POST /historial-clinico/organizaciones/:idOrganizacion/mascotas/:idMascota`.
- `PATCH /historial-clinico/organizaciones/:idOrganizacion/:idHistorial`.

## Adopciones

- `GET /adopciones/publicaciones` y
  `GET /adopciones/publicaciones/:idPublicacion`.
- `POST /adopciones/publicaciones` y
  `PATCH /adopciones/publicaciones/:idPublicacion/cerrar`.
- `POST|GET /adopciones/publicaciones/:idPublicacion/solicitudes`.
- `GET /adopciones/solicitudes/mias`.
- `PATCH /adopciones/solicitudes/:idSolicitud/revision` y `/cancelar`.

## Notificaciones y administración

- `GET /notificaciones`, `PATCH /notificaciones/:idNotificacion/leer`.
- Socket.IO: enviar el access token como `auth.token`; evento entrante
  `notificacion:nueva`. La API REST conserva el historial al reconectar.
- `GET /admin/resumen`, `GET /admin/usuarios`.
- `PATCH /admin/usuarios/:idUsuario/estado`.
- `PUT /admin/usuarios/:idUsuario/roles`.

## Estados relevantes

- Mascota: `a_salvo`, `perdido`, `en_adopcion`.
- Extravío: `activo`, `resuelto`, `cancelado`.
- Avistamiento: `registrado`, `revisado`, `descartado`.
- Coincidencia: `pendiente`, `confirmada`, `descartada`.
- Publicación: `disponible`, `cerrada`, `cancelada`.
- Solicitud: `pendiente`, `aprobada`, `rechazada`, `cancelada`.
