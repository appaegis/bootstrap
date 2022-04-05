mkdir ..\..\se_win
mkdir ..\..\se_win\log
copy bin\frpc.exe ..\..\se_win
copy isrgrootx1_and_trustid-x3-root.pem ..\..\se_win


REM
REM Generate a frpc.ini for run from local dir
REM
> ..\..\se_win\frpc.ini (
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
@echo.log_file=log\se2.log
@echo.log_level=debug
@echo.log_max_days=3
)


> ..\..\se_win\appaegis-se2-win.bat (
@echo.set auth_token=%1
@echo.set auth_secret=%2
@echo.set server_validation_code=%3
@echo.set server_addr=%4
@echo.set network_type=%5
@echo.set network_name=%6
@echo.set service_edge_number=%7
@echo.set label=%8
@echo.set serialno=%9
@echo.frpc.exe
)

cd ..\..\se_win
dir

sc create "appaegis-se2-win" start= delayed-auto displayname= "appaegis-se2-win" binpath= %cd%\appaegis-se2-win.bat

