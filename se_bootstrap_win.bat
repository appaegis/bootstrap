@echo off
setlocal
setlocal enabledelayedexpansion

@REM ========

:: Check for administrative privileges
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    :: Re-run the script with elevated privileges
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

@REM ========

:: If running as admin, continue the script, need to change to script's path
set "script_dir=%~dp0"
cd /d "%script_dir%"
echo Running as Administrator from %CD%

@REM ========

:: Check the Linux bootstrap file
set "paramfile=bootstrap.sh"
if exist "%~dp0%paramfile%" (
    REM found the parameter file
) else (
    echo Cannot find file "%paramfile%", please download it from management portal.
    pause
    goto :end
)

@REM ========

:: Parse Linux bootstrap file to get parameters
set "pattern=bash se_bootstrap.sh"
for /f "delims=" %%A in (%paramfile%) do (
    echo %%A | findstr "^%pattern%" > nul
    if %errorlevel% equ 0 (
        set "targetLine=%%A"
    )
)

@REM ========

rem Parse the parameters in the target line
set targetLine=!targetLine:%pattern%=!
set i=1
for %%B in (%targetLine%) do (
    set "param[!i!]=%%B"
    set /a i+=1
)
set /a count=i-1
echo Found %count% parameters
if %count% lss 9 (
    echo Only %count% parametes found, please check %paramfile%
    pause
    goto :end
)

@REM ========

:: Check the install ZIP file
set "zipFile=win-bootstrap.zip"
if exist "%~dp0%zipFile%" (
    REM zip file exists in current dir
) else (
    curl -fsSL https://raw.githubusercontent.com/appaegis/bootstrap/master/win-bootstrap.zip -o win-bootstrap.zip
    :: Check for errors
    if %errorlevel% neq 0 (
        echo Error downloading the file.
        pause
        goto :end
    ) else (
        echo File downloaded successfully.
    )
)

@REM ========

:: Extract files from ZIP file
set "tempDir=win-bootstrap-files"
if not exist "%tempDir%" mkdir "%tempDir%"
:: Use PowerShell to extract the ZIP file
powershell -Command "Expand-Archive -Path '%zipFile%' -DestinationPath '%tempDir%' -Force"
:: Move the selected files to the destination directory (e.g., *.txt)
for /r "%tempDir%" %%F in (*.exe *.pem) do (
    move "%%F" .
)

@REM ========

@REM
@REM check file checksum
@REM
@echo Please verify binary SHA1 checksum is: 8bf37ef3c4faa0852774ed677e7f226af941e62e
certutil -hashfile mammothfrpc.exe sha1

@REM
@REM copy files from the target folder
@REM
@mkdir %PROGRAMDATA%\Mammoth\se_win
@mkdir %PROGRAMDATA%\Mammoth\se_win\log
@move mammothfrpc.exe %PROGRAMDATA%\Mammoth\se_win\
@move isrgrootx1_and_trustid-x3-root.pem %PROGRAMDATA%\Mammoth\se_win\

@cd %PROGRAMDATA%\Mammoth\se_win

@REM
@REM Generate a frpc.ini for run from local dir
@REM
> frpc.ini (
@echo.[common]
@echo.tls_enable=true
@echo.tls_trusted_ca_file = isrgrootx1_and_trustid-x3-root.pem
@echo.
@echo.login_fail_exit=false
@echo.
@echo.log_file=log/se2.log
@echo.log_level=debug
@echo.log_max_days=3
)


@REM
@REM Generate a batch file to start with env variable
@REM
> mammoth-se2-win.bat (
@echo.set auth_token=%param[1]%
@echo.set auth_secret=%param[2]%
@echo.set server_validation_code=%param[3]%
@echo.set server_addr=%param[4]%
@echo.set network_type=%param[5]%
@echo.set network_name=%param[6]%
@echo.set service_edge_number=%param[7]%
@echo.set label=%param[8]%
@echo.set serialno=%param[9]%
@echo.cd %cd%
@echo.mammothfrpc.exe
)


@REM
@REM Generate XML config for the Task Scheduler
@REM
> mammoth-se2-task.xml (
@echo.^<?xml version="1.0" encoding="UTF-16"?^>
@echo.^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
@echo.  ^<Triggers^>
@echo.    ^<BootTrigger^>
@echo.      ^<Enabled^>true^</Enabled^>
@echo.    ^</BootTrigger^>
@echo.  ^</Triggers^>
@echo.  ^<Principals^>
@echo.    ^<Principal id="Author"^>
@echo.      ^<UserId^>S-1-5-18^</UserId^>
@echo.      ^<RunLevel^>LeastPrivilege^</RunLevel^>
@echo.    ^</Principal^>
@echo.  ^</Principals^>
@echo.  ^<Settings^>
@echo.    ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
@echo.    ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
@echo.    ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
@echo.    ^<AllowHardTerminate^>true^</AllowHardTerminate^>
@echo.    ^<StartWhenAvailable^>true^</StartWhenAvailable^>
@echo.    ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
@echo.    ^<IdleSettings^>
@echo.      ^<StopOnIdleEnd^>false^</StopOnIdleEnd^>
@echo.      ^<RestartOnIdle^>false^</RestartOnIdle^>
@echo.    ^</IdleSettings^>
@echo.    ^<AllowStartOnDemand^>true^</AllowStartOnDemand^>
@echo.    ^<Enabled^>true^</Enabled^>
@echo.    ^<Hidden^>false^</Hidden^>
@echo.    ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
@echo.    ^<WakeToRun^>false^</WakeToRun^>
@echo.    ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
@echo.    ^<Priority^>7^</Priority^>
@echo.    ^<RestartOnFailure^>
@echo.      ^<Interval^>PT5M^</Interval^>
@echo.      ^<Count^>300^</Count^>
@echo.    ^</RestartOnFailure^>
@echo.  ^</Settings^>
@echo.  ^<Actions Context="Author"^>
@echo.    ^<Exec^>
@echo.      ^<Command^>%cd%\mammoth-se2-win.bat^</Command^>
@echo.    ^</Exec^>
@echo.  ^</Actions^>
@echo.^</Task^>
)


dir

schtasks /create /f /xml mammoth-se2-task.xml /tn mammoth-se2-task
schtasks /run /tn mammoth-se2-task
schtasks /query /v /fo list /tn mammoth-se2-task
pause

:end
endlocal
