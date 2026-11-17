# PetID — contrato inicial del backend

Base local: `http://localhost:3000/api`

## Flujo de escaneo desde cámara

- `POST /avistamientos/escanear` — escaneo anónimo.
- `POST /avistamientos/escanear/registrado` — requiere autenticación.
- Formato `multipart/form-data`: archivo `foto`, `tipo_captura` con `cerca`,
  `lejos` o `desconocida`, y campo `datos` con JSON de fecha, ubicación y una
  descripción opcional.
- El backend crea el avistamiento, detecta y recorta el animal, genera DINOv2,
  combina evidencia visual y contextual, persiste hasta cinco coincidencias y
  notifica a los propietarios. Toda coincidencia requiere revisión humana.

## Alertas geográficas y dispositivos

- `PUT /notificaciones/ubicacion-alertas` guarda de forma privada una ubicación
  reciente y un radio de hasta 50 km.
- `DELETE /notificaciones/ubicacion-alertas` elimina la suscripción y ubicación.
- `POST /notificaciones/dispositivos` registra un token FCM y su plataforma.
- `DELETE /notificaciones/dispositivos` elimina el token enviado en el body.
- Cada usuario recibe como máximo una alerta por reporte de extravío. Las
  notificaciones se persisten, se emiten por Socket.IO y usan FCM si está activo.

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

Los listados y detalles de mascotas, extravios y avistamientos incluyen sus
fotografias. Las URL bajo `/storage/imagenes/` pueden mostrarse desde el origen
web configurado sin exponer el directorio del servidor.

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

- `GET /mapas/configuracion` - devuelve la configuracion publica para MapLibre
  y OpenFreeMap; nunca expone la clave de Geoapify.

## Coincidencias

- `POST /coincidencias/visuales/buscar` — autenticado, `multipart/form-data`
  con el archivo `foto`. Roboflow detecta el perro o gato, Sharp recorta la
  región y DINOv2 devuelve las cinco mascotas con extravío activo más similares.
  La similitud orienta la búsqueda y siempre requiere confirmación humana.
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
- `GET /admin/organizaciones` - incluye pendientes y admite `tipo` y
  `verificada` como filtros.
- `GET /admin/extravios` y `GET /admin/avistamientos` - listados moderables.
- `PATCH /admin/avistamientos/:idAvistamiento/estado` - cambia entre
  `registrado`, `revisado` y `descartado`.

## Estados relevantes

- Mascota: `a_salvo`, `perdido`, `en_adopcion`.
- Extravío: `activo`, `resuelto`, `cancelado`.
- Avistamiento: `registrado`, `revisado`, `descartado`.
- Coincidencia: `pendiente`, `confirmada`, `descartada`.
- Publicación: `disponible`, `cerrada`, `cancelada`.
- Solicitud: `pendiente`, `aprobada`, `rechazada`, `cancelada`.
