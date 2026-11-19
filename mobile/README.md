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

### Acceso y registro

Desde `backend/`, ejecuta `pnpm install` y `pnpm db:migrate` antes de iniciar
la API. El registro de veterinaria o refugio crea una solicitud de organización
pendiente de revisión. La ubicación es opcional y el sistema pide permiso en
el teléfono únicamente si el usuario selecciona alertas por zona.

Para verificar una cuenta o restablecer la contraseña, copia el enlace del
correo y pégalo en el formulario correspondiente de PetID. Con
`DEV_EMAIL_MODE=log` y sin SMTP, el enlace de prueba aparece en la terminal
del backend. Para entregarlo a un correo real, configura SMTP.

Para habilitar Google, registra la app Android `hn.petid.petid` con el SHA‑1
de su firma en Google Cloud. Crea además un cliente OAuth de tipo web y usa su
ID en `GOOGLE_SIGN_IN_CLIENT_ID` del backend y
`--dart-define=PETID_GOOGLE_CLIENT_ID=TU_ID_WEB` en Flutter. Para iOS, registra
también su bundle ID, pasa `--dart-define=PETID_GOOGLE_IOS_CLIENT_ID=TU_ID_IOS`
y pon el ID invertido como `PETID_GOOGLE_IOS_URL_SCHEME` en
`ios/Flutter/PetIdGoogle.local.xcconfig`. Usa HTTPS en producción. En
desarrollo, Google también admite la conexión local mediante `adb reverse`.

La bienvenida abre el registro, el inicio de sesión y el formulario público de
avistamiento. El backend requiere verificar el correo antes de iniciar sesión.
Los reportes con foto se envían al endpoint de escaneo y los reportes sin foto
se envían al endpoint de avistamientos. Ambos admiten una referencia escrita
del lugar. La sesión se guarda en almacenamiento seguro del dispositivo.
