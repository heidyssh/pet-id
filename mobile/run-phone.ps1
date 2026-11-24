# Abre PetID en el celular conectado por Wireless debugging.
# Crea el puente al backend (puerto 3000) y luego ejecuta la app.
# Uso, desde la carpeta mobile:  .\run-phone.ps1

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

$devices = & $adb devices | Select-Object -Skip 1 |
    Where-Object { $_ -match '\tdevice$' } |
    ForEach-Object { ($_ -split '\t')[0] }

if (-not $devices) {
    Write-Host 'No hay ningún celular conectado. Activa Wireless debugging y usa adb connect IP:PUERTO.' -ForegroundColor Yellow
    exit 1
}

foreach ($device in $devices) {
    & $adb -s $device reverse tcp:3000 tcp:3000 | Out-Null
    Write-Host "Puente al backend listo en $device" -ForegroundColor Green
}

flutter run -d $devices[0] --dart-define-from-file=petid.local.json
