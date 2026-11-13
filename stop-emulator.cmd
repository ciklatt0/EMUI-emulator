@echo off
REM ============================================================================
REM  HarmonyOS Emulator - DURDUR
REM
REM  1) QEMU'yu (ve denetleyiciyi) kapatir
REM  2) logu zaman damgasiyla arsivler
REM  3) KOŞU ÖZETI basar  (scripts/91-log-summary.sh)
REM
REM  OZET NEDEN AYRI BIR ADIM: log 7000 satira ulasiyor ve kritik bilgi
REM  (apexd neden oldu, binder geldi mi, Zygote basladi mi) 5 satirlik
REM  bir blokun icinde kayboluyor. 'findstr ile 3 kelime ara' her seferinde
REM  yanlis pozitif/negatif veriyordu.
REM ============================================================================
setlocal

set "LOGS=%~dp0logs"
set "WSL_SCRIPT=%~dp0scripts\91-log-summary.sh"

if not exist "%LOGS%" (
  echo [HATA] logs klasoru yok: %LOGS%
  pause
  exit /b 1
)

echo [*] Emulasyon durduruluyor...
wsl -d Ubuntu -u root -- pkill -9 -f qemu-system 2>nul
wsl -d Ubuntu -u root -- pkill -9 -f supervise 2>nul
timeout /t 2 >nul

REM --- logu arsivle (zaman damgasiyla) -------------------------------------
if exist "%LOGS%\boot-zygote.log" (
  if not exist "%LOGS%\archive" mkdir "%LOGS%\archive"
  for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set STAMP=%%t
  move /y "%LOGS%\boot-zygote.log" "%LOGS%\archive\boot-zygote-%STAMP%.log" >nul
  echo [*] Log arsivlendi: logs\archive\boot-zygote-%STAMP%.log
  set "LASTLOG=%~dp0logs\archive\boot-zygote-%STAMP%.log"
) else (
  echo [*] Log dosyasi yok, arsivlenecek bir sey yok.
  set "LASTLOG="
)

REM --- KOŞU ÖZETI ----------------------------------------------------------
REM DIKKAT: ozet arsivlenmis logdan okunur, yoksa script bulamaz
REM (81-boot-zygote.log calisma sirasinda QEMU tarafindan 'file:' ile
REM  acilip yaziliyor ve biz durdururken yarim kalmis olabilir).
if defined LASTLOG (
  wsl -d Ubuntu -u root -- bash "%WSL_SCRIPT%" "%LASTLOG%"
) else (
  echo [!] Arsivlenmis log yok, ozet uretilemedi.
)

echo.
echo [*] Durduruldu. Tekrar baslatmak icin: start-emulator.cmd
timeout /t 5 >nul
endlocal