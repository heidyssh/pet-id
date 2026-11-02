# 🐾 PetID – Sistema Inteligente de Identificación y Rescate de Mascotas

PetID es una plataforma web y móvil diseñada para facilitar la identificación, localización y recuperación de mascotas extraviadas mediante reconocimiento fotográfico, geolocalización y alertas en tiempo real.

El sistema permite registrar mascotas, reportar extravíos y publicar avistamientos con o sin fotografía. Además, contempla un panel administrativo para veterinarias y refugios, historiales clínicos y gestión de adopciones.

## Tecnologías

| Componente | Tecnología |
|---|---|
| Backend | Node.js + Express.js |
| Frontend web | React + Tailwind CSS |
| Aplicación móvil | Flutter + Dart |
| Base de datos | PostgreSQL + PostGIS |
| Administrador de paquetes | pnpm / Flutter pub |
| Comunicación | API REST + Socket.io |
| Autenticación | JWT |
| Herramientas | VS Code, Git, pgAdmin |

## Estructura del proyecto

```text
pet-id/
├── backend/           # API REST y lógica del servidor
├── web/               # Panel administrativo React
├── mobile/            # Aplicación móvil Flutter
├── database/          # Scripts SQL y estructura de la BD
├── docs/              # Diagramas y documentación
├── .gitignore
└── README.md
```

La aplicación móvil y la plataforma web consumirán la misma API REST y utilizarán una única base de datos.

## Requisitos previos

Antes de comenzar, se deben instalar:

- Node.js (versión LTS).
- pnpm (versión compatible con Node.js).
- PostgreSQL.
- PostGIS.
- pgAdmin 4.
- Visual Studio Code.
- Git.
- Flutter SDK y sus herramientas de desarrollo (para la aplicación móvil).

Verificar las instalaciones:

```bash
node -v
npm -v
pnpm -v
git --version
flutter doctor
```

El comando `flutter doctor` será necesario para quienes desarrollen o ejecuten la aplicación móvil.

## Instalación y configuración

### 1. Clonar el repositorio

```bash
git clone URL_DEL_REPOSITORIO
cd pet-id
```

Reemplazar `URL_DEL_REPOSITORIO` por la URL correspondiente al proyecto.

### 2. Instalar pnpm

Si todavía no está instalado:

```bash
npm install -g pnpm
```

Verificar:

```bash
pnpm -v
```

### 3. Configurar el backend

Desde la carpeta principal del proyecto:

```bash
cd backend
pnpm install
```

Este comando instala automáticamente las dependencias registradas en `package.json`.

**Dependencias iniciales:**

| Dependencia | Función |
|---|---|
| express | Crear la API REST |
| cors | Configurar solicitudes entre aplicaciones |
| dotenv | Cargar variables de entorno |
| pg | Conectar con PostgreSQL |
| nodemon | Reiniciar el servidor durante el desarrollo |

No es necesario instalar cada paquete manualmente si ya está registrado en `package.json`.

### 4. Configurar PostgreSQL

Crear una base de datos llamada:

```sql
CREATE DATABASE petid;
```

Posteriormente, conectarse a la base de datos `petid` y ejecutar:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Los scripts para crear las tablas y relaciones estarán disponibles en la carpeta `database/` cuando finalice su implementación.

### 5. Configurar variables de entorno

Dentro de `backend/`, crear un archivo `.env` tomando como referencia `.env.example` cuando esté disponible.

Variables previstas:

```env
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=petid
DB_USER=postgres
DB_PASSWORD=TU_CONTRASENA

JWT_SECRET=TU_CLAVE_SECRETA
```

Cada integrante debe colocar sus credenciales locales.

**Importante:** nunca subir el archivo `.env` al repositorio ni compartir contraseñas o claves reales.

### 6. Ejecutar el backend

Una vez configurados los scripts del servidor en `backend/package.json`, el comando previsto será:

```bash
pnpm dev
```

Actualmente está pendiente la configuración del servidor Express y su script de ejecución.

### 7. Configurar el frontend web

Cuando el proyecto React esté creado dentro de `web/`:

```bash
cd web
pnpm install
pnpm dev
```

El segundo comando iniciará el servidor de desarrollo de React una vez configurado Vite.

### 8. Configurar la aplicación móvil

Una vez creado el proyecto Flutter dentro de `mobile/`:

```bash
cd mobile
flutter pub get
flutter run
```

Para ejecutar la aplicación será necesario tener configurado un dispositivo o emulador compatible.

## Funcionalidades del sistema

### Aplicación móvil (Flutter)

- Registro e inicio de sesión.
- Registro y gestión de mascotas.
- Reporte de mascotas extraviadas.
- Registro de avistamientos con o sin fotografía.
- Reconocimiento fotográfico mediante detección y recorte automático (Smart Crop).
- Búsqueda de posibles coincidencias.
- Geolocalización y alertas de proximidad.
- Carné digital de vacunación con consulta offline.

### Plataforma web (React)

- Panel administrativo.
- Gestión de veterinarias y refugios.
- Consulta y moderación de reportes.
- Administración de historiales clínicos y vacunas.
- Gestión de publicaciones y solicitudes de adopción.
- Estadísticas y visualización de zonas de extravío.

### Backend (Node.js + Express)

- API REST compartida.
- Autenticación y autorización.
- Gestión de usuarios y mascotas.
- Registro de extravíos y avistamientos.
- Integración del reconocimiento fotográfico.
- Consultas geográficas mediante PostGIS.
- Comunicación en tiempo real mediante Socket.io.

## Base de datos

Se utilizará PostgreSQL con la extensión PostGIS.

El diseño inicial está organizado en 16 tablas relacionadas, considerando normalización, integridad referencial y rendimiento.

Entre las principales entidades se encuentran:

- Usuarios, roles y organizaciones.
- Mascotas, especies, razas y fotografías.
- Reportes de extravío y avistamientos.
- Coincidencias fotográficas o descriptivas.
- Historial clínico.
- Publicaciones y solicitudes de adopción.

El diagrama entidad-relación se conservará en `docs/` y los scripts SQL en `database/`.

## Trabajo colaborativo

PetID será desarrollado por dos integrantes mediante un repositorio compartido.

### Recomendaciones

1. Trabajar en ramas separadas para cada funcionalidad.
2. Descargar los cambios recientes antes de comenzar.
3. Realizar commits claros y descriptivos.
4. No subir `node_modules/`, archivos `.env` ni información sensible.
5. Mantener actualizados los archivos de dependencias y sus respectivos archivos de bloqueo.
6. Actualizar este README cuando cambien las instrucciones de instalación o ejecución.

### Comandos básicos de Git

Obtener cambios recientes:

```bash
git pull
```

Crear una rama:

```bash
git switch -c nombre-rama
```

Guardar cambios:

```bash
git add .
git commit -m "Descripcion de los cambios"
```

Publicar la rama:

```bash
git push -u origin nombre-rama
```

Antes de fusionar cambios a la rama principal, revisar que el proyecto continúe funcionando.

## Estado del proyecto

- [x] Análisis de requisitos.
- [x] Diseño lógico inicial de la base de datos.
- [x] Definición de tecnologías.
- [x] Organización inicial de carpetas.
- [x] Inicialización del backend con pnpm.
- [x] Instalación de dependencias iniciales.
- [ ] Configuración del servidor Express.
- [ ] Implementación de la base de datos.
- [ ] Conexión de PostgreSQL con Node.js.
- [ ] Desarrollo de endpoints REST.
- [ ] Configuración del frontend React.
- [ ] Configuración de Flutter.
- [ ] Integración del reconocimiento fotográfico.
- [ ] Implementación de alertas y geolocalización.
- [ ] Pruebas e integración final.

---

**Proyecto académico: PetID**

Universidad Tecnológica Centroamericana (CEUTEC) – Sede La Ceiba

Carrera: Ingeniería en Informática

Asignatura: Desarrollo de Aplicaciones de Vanguardia
