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
Si usas un teléfono Android conectado por USB, puedes redirigir el puerto con
`adb reverse tcp:3000 tcp:3000` y ejecutar
`flutter run --dart-define=PETID_API_URL=http://127.0.0.1:3000/api`.
Para compilar en modo release, configura `PETID_API_URL` con una URL HTTPS.

La bienvenida abre el registro, el inicio de sesión y el formulario público de
avistamiento. El backend requiere verificar el correo antes de iniciar sesión.
Los reportes con foto se envían al endpoint de escaneo y los reportes sin foto
se envían al endpoint de avistamientos. Ambos admiten una referencia escrita
del lugar. La sesión se guarda en almacenamiento seguro del dispositivo.
