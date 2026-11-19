# PetID móvil

Aplicación de Flutter para los usuarios de PetID. El panel de administración se
desarrolla aparte en `web/`.

Desde la raíz del repositorio, abre dos terminales. En la primera, inicia el
backend con PostgreSQL activo y las migraciones y semillas aplicadas.

```powershell
cd backend
pnpm dev
```

En la segunda, con el emulador Android abierto:

```powershell
cd mobile
flutter pub get
flutter run
```

El emulador Android usa por defecto `http://10.0.2.2:3000/api` en modo debug.
Si usas un teléfono Android conectado por USB o **Wireless debugging**,
redirige el puerto del backend a ese dispositivo. Usa el ID de `flutter devices`:

```powershell
$petidDevice = 'ID_DEL_ANDROID'
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s $petidDevice reverse tcp:3000 tcp:3000
flutter run -d $petidDevice --dart-define=PETID_API_URL=http://127.0.0.1:3000/api
```

Para compilar en modo release, configura `PETID_API_URL` con una URL HTTPS.

### Generar el APK sin ocupar espacio local

El workflow **Generar APK Android** compila la aplicación en GitHub y permite
descargar solamente el APK. No requiere instalar Gradle ni generar la carpeta
`build/` en la computadora.

1. Conecta la computadora y el teléfono al mismo Wi-Fi.
2. Ejecuta `ipconfig` y busca la dirección IPv4 de la computadora, por ejemplo
   `192.168.1.20`.
3. Inicia el backend con `pnpm dev` y permite Node.js en la red privada si
   Windows muestra una solicitud del firewall.
4. Sube los cambios a GitHub y abre **Actions > Generar APK Android > Run
   workflow**.
5. En `api_url`, escribe `http://IP_DE_LA_COMPUTADORA:3000/api`; por ejemplo,
   `http://192.168.1.20:3000/api`.
6. Cuando termine, abre la ejecución, descarga el artefacto
   `PetID-Android-N`, descomprímelo e instala `app-debug.apk` en el teléfono.

El APK de desarrollo permite HTTP para comunicarse con el backend local. Solo
funcionará mientras el backend esté encendido y ambos dispositivos puedan
verse en la misma red. La versión de producción continúa exigiendo HTTPS.

### Acceso y registro

Desde `backend/`, ejecuta `pnpm install` y `pnpm db:migrate` antes de iniciar
la API. El registro de veterinaria o refugio crea una solicitud de organización
pendiente de revisión. La ubicación es opcional y el sistema pide permiso en
el teléfono únicamente si el usuario selecciona alertas por zona.

Para verificar una cuenta o restablecer la contraseña, copia el enlace del
correo y pégalo en el formulario correspondiente de PetID. Con
`DEV_EMAIL_MODE=log` y sin SMTP, el enlace de prueba aparece en la terminal
del backend. Para entregarlo a un correo real, configura SMTP.

La bienvenida abre el registro, el inicio de sesión y el formulario público de
avistamiento. Durante esta etapa de desarrollo, las cuentas pueden iniciar
sesión sin verificación por correo.
Los reportes con foto se envían al endpoint de escaneo y los reportes sin foto
se envían al endpoint de avistamientos. Ambos admiten una referencia escrita
del lugar. La sesión se guarda en almacenamiento seguro del dispositivo.
