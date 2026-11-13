@echo off
REM ============================================================================
REM  HarmonyOS Emulator (EVR-L29 EMUI 9/10) - tek tik baslatir
REM
REM  Ne yapar:
REM    1) Calisan bir QEMU var mi diye BAKAR (otomatik oldurmez).
REM    2) Windows Terminal'de bir pencere acar ve emulasyonu calistirir.
REM    3) Pencere acilamazsa yedek olarak cmd.exe ile devam eder.
REM
REM  Kapatmak icin: pencereyi kapat.
REM ============================================================================

setlocal

echo [*] HarmonyOS Emulator (EVR-L29) baslatiliyor...

REM --- 1) Calisan QEMU var mi? ------------------------------------------------
for /f "tokens=*" %%p in ('wsl -d Ubuntu -u root -- pgrep -f qemu-system-aarch64 2^>nul') do set "RUNNINGQEMU=%%p"
if defined RUNNINGQEMU (
  echo [!] Zaten calisan bir emulasyon var. Iki ornek ayni disk imajini
  echo     ve ayni log dosyasini paylasirsa biri digerini bozar.
  echo.
  echo     Durdurmak icin : scripts\stop-emulator.cmd
  echo     Pencereyi kapattiktan sonra tekrar deneyin.
  echo.
  pause
  exit /b 1
)
set "RUNNINGQEMU="

wsl -d Ubuntu -u root -- rm -f /tmp/harmony-emulator.lock 2>nul

echo [*] Eski kilit temizlendi.

REM --- 2) Windows Terminal ile pencere ac ------------------------------------
where wt.exe >nul 2>nul
if %errorlevel%==0 (
  echo [*] Windows Terminal aciliyor...
  start "" wt.exe -w 0 new-tab --title "HarmonyOS EVR-L29" wsl.exe -d Ubuntu -u root -- bash /root/harmony-build/scripts/81-boot-zygote-evr.sh
  goto :done
)

REM --- 3) Yedek: cmd.exe icinde dogrudan calistir ----------------------------
echo [!] Windows Terminal bulunamadi, cmd ile devam ediliyor.
wsl -d Ubuntu -u root -- bash /root/harmony-build/scripts/81-boot-zygote-evr.sh

:done
echo.
echo [*] Pencere acildi. Emulasyonu kapatmak icin pencereyi kapatin.
echo [*] Canli seri gunlugu ayrica: logs\boot-zygote-evr.log
endlocal