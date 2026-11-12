# PetID — integraciones externas

## Visión y Smart Crop

La implementación seleccionada para la primera integración es Google Cloud
Vision Object Localization. Se activa únicamente con:

```env
VISION_PROVIDER=google
GOOGLE_VISION_API_KEY=...
```

Sin credenciales, el backend normaliza y conserva la imagen, deja el
procesamiento pendiente y no inventa detecciones. Con Google configurado,
localiza objetos `Dog`, `Cat`, `Animal`, `Mammal` o `Pet` y Sharp genera el
recorte. Object Localization no identifica individualmente una mascota.

Roboflow es la opción recomendada para una segunda etapa con un detector o
modelo personalizado validado con perros y gatos. Requiere elegir el proyecto,
versión y política de datos antes de añadir su adaptador. TensorFlow.js es un
runtime y necesita un modelo apropiado. `@vladmandic/face-api` usa modelos de
rostros humanos y su repositorio está archivado; no se adopta para mascotas.
AWS Rekognition DetectLabels también detecta objetos genéricos, no identidad
individual.

Referencias primarias:

- https://docs.cloud.google.com/vision/docs/object-localizer
- https://cloud.google.com/vision/pricing
- https://roboflow.com/pricing
- https://github.com/roboflow/inference
- https://www.tensorflow.org/js/models
- https://github.com/vladmandic/face-api
- https://docs.aws.amazon.com/rekognition/latest/APIReference/API_DetectLabels.html

## Google Maps

El backend no necesita una clave de Maps para búsquedas entre reportes: usa
PostGIS. El proxy de Geocoding usa `GOOGLE_MAPS_SERVER_API_KEY`, que debe estar
restringida por IP y únicamente a Geocoding API. React debe usar una clave
separada y restringida por dominio para Maps JavaScript
API; Flutter debe usar claves separadas y restringidas por paquete/firma para
Android e identificador de bundle para iOS. Places o Geocoding solo deben
habilitarse si se implementa búsqueda de lugares/direcciones. No se deben
reutilizar estas claves como `GOOGLE_VISION_API_KEY`.

## Correo

En desarrollo, `DEV_EMAIL_MODE=log` muestra el correo de verificación en la
consola. En producción se exige SMTP real y la ausencia de configuración falla
de forma segura. Para forzar SMTP localmente use `DEV_EMAIL_MODE=smtp`.
