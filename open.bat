:: win7-efi-gop-boot-tool
:: Open efi gop suporrt for Windows 7
:: Author: muink

@echo off&title Open efi gop suporrt for Windows 7
%~1 mshta vbscript:createobject("shell.application").shellexecute("%~f0","::","","runas",1)(window.close)&exit
:: =============The following code is based on UsbBoot-Installer=============
net session>nul 2>nul||color 4F&&echo.Please run as Administrator&&pause>nul&&exit
:init
cd /d %~dp0
set "reg_system_path=HKLM\SYSTEM"
set "reg_software_path=HKLM\SOFTWARE"
:choise_install_mode
cls
echo.Choise the installation mode (Default 1)
echo.     0. Exit
echo.     1. Open efi gop support for the current system
echo.     2. Open efi gop support for other windows system
set "install_mode=1"
set /p install_mode=Choise: 
if not "%install_mode%"=="0" (
   if not "%install_mode%"=="1" (
      if not "%install_mode%"=="2" (
         goto choise_install_mode
      ) else goto menu_2
   ) else goto menu_1
) else cls&goto END

:menu_1
cls
set "install_volume=%SystemDrive:~0,1%"
::checksystem
set install_version=
call:[CheckSystem] install_version
call:[Install]
::Disable Vesa Bios
bcdedit /set {current} novesa on
::Disable Boot Display
rem bcdedit /set {current} quietboot on
::Boot Log Initialization "%WINDIR%\Ntbtlog.txt"
rem bcdedit /set {current} bootlog yes
::Boot Status Policy - Ignore all boot failures and start Windows normally.(Default)
rem bcdedit /set {current} bootstatuspolicy IgnoreAllFailures
goto COMPLETE

:menu_2
cls
echo.
set "install_volume=0"
set /p install_volume=Enter drive letter of the system: 
echo.%install_volume%|findstr /i "\<[a-z,A-Z]\>">nul||goto menu_2
echo.%install_volume%|findstr /i "\<[c,C]\>">nul&&goto menu_2
::checksystem
set "reg_system_path=HKLM\USBOSYS"
set "reg_system_file=%install_volume%:\Windows\System32\config\SYSTEM"
set "reg_software_path=HKLM\USBOSOFT"
set "reg_software_file=%install_volume%:\Windows\System32\config\SOFTWARE"
set install_version=
set error_m2=
call:[CheckSystem] install_version error_m2 reg_system_path reg_system_file reg_software_path reg_software_file
if "%error_m2%"=="2" (
   echo.
   echo.This volume no available system exist or system registry corrupted.
   echo.
   echo.Press any key to back.&pause>nul
   goto menu_2
)
if "%error_m2%"=="8" (
   echo.
   echo.This volume no available system exist or system registry corrupted.
   echo.
   echo.Press any key to back.&pause>nul
   goto menu_2
)
call:[Install]
call:[OtherBCD]
goto COMPLETE





:[CheckSystem]
setlocal enabledelayedexpansion
if "%install_mode%"=="1" (
   set "syspath=%reg_system_path%"
   set "softpath=%reg_software_path%"
) else (
   set "syspath=!%~3!"
   set "sysfile=!%~4!"
   set "softpath=!%~5!"
   set "softfile=!%~6!"
   rem File Check
   if not exist "!sysfile!" (
      for /f %%i in ("2") do endlocal&set "%~2=%%i"&goto :eof
   )
   if not exist "!softfile!" (
      for /f %%i in ("8") do endlocal&set "%~2=%%i"&goto :eof
   ) else reg load !softpath! "!softfile!"
)
call:[VerifySystemVersion] vers %softpath% ProductName EditionID CurrentVersion
for /f "delims=" %%i in ("%vers%") do endlocal&set "%~1=%%i"
goto :eof


:[VerifySystemVersion]
setlocal enabledelayedexpansion
call:[CatNTInfo] %~2 %~3 name
call:[CatNTInfo] %~2 %~4 edition
call:[CatNTInfo] %~2 %~5 version
if not "%install_mode%"=="1" reg unload %~2>nul
echo.%version%|findstr "\<[0-9,.]*\>">nul&&(
   for /f "tokens=1-2 delims=." %%i in ("%version%") do (
      set "version=%%i%%j"
   )
)||set /a "version+=0"
::Return version code
if %version% lss 51 (
   set "version=winxp"
) else (
   if %version% lss 60 (
      set "version=winxp"
   ) else (
      if %version% lss 62 (
         set "version=win7"
         set "ottlb=1"
      ) else (
         if %version% leq 63 (
            set "version=win8"
         ) else (
            if %version% gtr 63 (
               set "version=win11"
            )
         )
      )
   )
)
:[VerifySystemVersion]loop
cls
echo.&echo.Identified system is "%name%" edition is "%edition%"&echo.
if not defined ottlb color CF&echo.Warning: Not support this system now.&goto END
set "ny=n"
set /p ny=Whether continue? [y/n]
color 07
if not "%ny%"=="n" (
   if not "%ny%"=="y" goto %~0loop
) else cls&goto END
for /f "delims=" %%i in ("%version%") do endlocal&set "%~1=%%i"
goto :eof


:[CatNTInfo]
setlocal enabledelayedexpansion
for /f "tokens=2* delims= " %%i in ('reg query "%~1\Microsoft\Windows NT\CurrentVersion" /v %~2 2^>nul^|findstr /i "\< *%~2 *REG_[a-z,A-Z]*"') do set "%~3=%%j"
if not defined %~3 set "%~3=NULL"
for /f "delims=" %%i in ("!%~3!") do endlocal&set "%~3=%%i"
goto :eof


:[Install]
setlocal enabledelayedexpansion
if not "%install_mode%"=="1" reg load %reg_system_path% "%reg_system_file%"
::Can not runing XP
for /f "tokens=2* delims= " %%i in ('reg query %reg_system_path%\select /v current /t reg_dword^|findstr /i current') do set /a "conum=%%j"
set "selectcontrol=%reg_system_path%\ControlSet00%conum%"
call:[UpdateServer]
if not "%install_mode%"=="1" reg unload %reg_system_path%
endlocal
goto :eof


:[UpdateServer]
reg add "%selectcontrol%\services\Vga" /v Start /t reg_dword /d 4 /f
reg add "%selectcontrol%\services\VgaSave" /v Start /t reg_dword /d 4 /f
goto :eof
:: ==========================================================================


:[OtherBCD]
cls
echo.&echo.Please use diskpart to assign a drive letter to the EFI partition of the hard disk where the target system resides&echo.
set /p bo_letter=Enter drive letter of the Boot partition: 
echo.%bo_letter%|findstr /i "\<[a-z,A-Z]\>">nul||goto [OtherBCD]
echo.%bo_letter%|findstr /i "\<[c,C]\>">nul&&goto [OtherBCD]
::Disable Vesa Bios
bcdedit /store %bo_letter%:\efi\Microsoft\boot\bcd /set {default} novesa on||goto [OtherBCD]
::Disable Boot Display
rem bcdedit /store %bo_letter%:\efi\Microsoft\boot\bcd /set {default} quietboot on||goto [OtherBCD]
::Boot Log Initialization "%WINDIR%\Ntbtlog.txt"
rem bcdedit /store %bo_letter%:\efi\Microsoft\boot\bcd /set {default} bootlog yes||goto [OtherBCD]
::Boot Status Policy - Ignore all boot failures and start Windows normally.(Default)
rem bcdedit /store %bo_letter%:\efi\Microsoft\boot\bcd /set {default} bootstatuspolicy IgnoreAllFailures||goto [OtherBCD]
goto :eof





:COMPLETE
cls
echo.
echo.Installation completed!
:END
echo.
echo.Press any key to exit.&pause>nul
echo."%~dp0"|findstr /i "%temp%">nul 2>nul&&rd /s /q "%~dp0">nul 2>nul
exit
