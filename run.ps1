# Script para lanzar VoyContigo
Write-Host "Iniciando VoyContigo (Frontend)..." -ForegroundColor Cyan
Write-Host "Nota: El Backend (Firebase) corre en la nube de Google 24/7, no necesitas iniciarlo manualmente." -ForegroundColor Yellow

# Limpiar caché por si acaso y correr
flutter clean
flutter run
