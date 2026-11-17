# PetID - integraciones externas

## Vision y Smart Crop

El backend incluye dos adaptadores de deteccion compatibles con el mismo flujo
de normalizacion y Smart Crop.

Google Cloud Vision Object Localization:

```env
VISION_PROVIDER=google
GOOGLE_VISION_API_KEY=...
```

Roboflow Serverless con un modelo preentrenado de deteccion de perros y gatos:

```env
VISION_PROVIDER=roboflow
ROBOFLOW_API_KEY=...
ROBOFLOW_MODEL_ID=proyecto/version
ROBOFLOW_API_URL=https://serverless.roboflow.com
DINO_MODEL_ID=onnx-community/dinov2-small
```

Sin credenciales, el backend normaliza y conserva la imagen, deja el
procesamiento pendiente y no inventa detecciones. Si el proveedor configurado
falla, conserva la imagen y registra el procesamiento como fallido para poder
reintentarlo posteriormente. Ambos proveedores localizan
al animal y permiten recortarlo, pero no identifican individualmente una
mascota. DINOv2 genera embeddings visuales para ordenar candidatos por
similitud, siempre con confirmacion humana.

El modelo de Roboflow debe elegirse comprobando que detecte perros y gatos y
que su licencia permita el uso previsto. El modelo configurado debe reevaluarse
si cambian su versión, licencia o disponibilidad.

## Similitud visual con DINOv2

Después de la detección, Sharp conserva un recorte con margen alrededor del
animal. `onnx-community/dinov2-small` convierte el recorte en un vector de 384
dimensiones normalizado. Se almacena un vector por fotografía en
`vectores_visuales`, de modo que una mascota puede tener varias vistas sin
entrenar nuevamente el modelo.

La búsqueda calcula similitud coseno, conserva la puntuación más alta por
mascota y devuelve hasta cinco mascotas con un reporte de extravío activo. Es
una ayuda para ordenar candidatos, no una identificación biométrica.

El modelo ONNX se descarga durante la primera inferencia y después se reutiliza
desde la caché local de Transformers.js.

## Mapas

PetID usa:

- MapLibre como motor de mapas en React y Flutter.
- OpenFreeMap como proveedor gratuito del mapa base.
- Geoapify para geocodificacion y busqueda de direcciones.
- PostgreSQL/PostGIS para distancias entre reportes almacenados.

El backend mantiene privada `GEOAPIFY_API_KEY`, restringe resultados a Honduras
y publica unicamente la configuracion segura mediante
`GET /api/mapas/configuracion`.

```env
GEOAPIFY_API_KEY=...
MAP_STYLE_URL=https://tiles.openfreemap.org/styles/liberty
```

La atribucion de OpenStreetMap y Geoapify debe permanecer visible donde se
presenten mapas o resultados geocodificados.

## Estado implementado del reconocimiento

PetID usa actualmente `dog-and-cat-face-detection/1` para detección y
`onnx-community/dinov2-small` para vectores de 384 dimensiones. Los escaneos
guardan por separado `puntuacion_visual` y `puntuacion_contexto`; la puntuación
combinada ordena candidatos y nunca se presenta como identidad confirmada.

```env
VISUAL_MATCH_MIN_SCORE=0.70
VISUAL_MATCH_LIMIT=5
```

## Alertas móviles y Firebase

Las notificaciones siempre se guardan en PostgreSQL y se emiten por Socket.IO.
FCM se activa únicamente cuando están presentes:

```env
FCM_PROJECT_ID=
FCM_CLIENT_EMAIL=
FCM_PRIVATE_KEY=
```

Sin esas credenciales, el registro de dispositivos y el resto del backend
continúan funcionando, pero no se envían notificaciones con la app cerrada.

## Correo

En desarrollo, `DEV_EMAIL_MODE=log` muestra el correo de verificacion en la
consola. En produccion se exige SMTP real y la ausencia de configuracion falla
de forma segura. Para forzar SMTP localmente use `DEV_EMAIL_MODE=smtp`.
