@REM
@REM check file checksum
@REM
@echo Please verify binary SHA1 checksum is: 8bf37ef3c4faa0852774ed677e7f226af941e62e
certutil -hashfile mammothfrpc.exe sha1

@REM
@REM copy files from the target folder
@REM
@mkdir %LOCALAPPDATA%\Mammoth\se_win
@mkdir %LOCALAPPDATA%\Mammoth\se_win\log
@move mammothfrpc.exe %LOCALAPPDATA%\Mammoth\se_win\
@move isrgrootx1_and_trustid-x3-root.pem %LOCALAPPDATA%\Mammoth\se_win\

@cd %LOCALAPPDATA%\Mammoth\se_win

@REM
@REM Generate a frpc.ini for run from local dir
@REM
> frpc.ini (
@echo.[common]
@echo.admin_addr = 127.0.0.1
@echo.admin_port = 7400
@echo.admin_user = admin
@echo.admin_pwd = appaegisse2
@echo.
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
@echo.set auth_token=%1
@echo.set auth_secret=%2
@echo.set server_validation_code=%3
@echo.set server_addr=%4
@echo.set network_type=%5
@echo.set network_name=%6
@echo.set service_edge_number=%7
@echo.set label=%8
@echo.set serialno=%9
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
@echo.      ^<LogonType^>S4U^</LogonType^>
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

