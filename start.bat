@echo off
rem Disable delayed expansion so the demo password's ! stays literal.
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"

rem Check prerequisites before opening any application windows.
where dotnet >nul 2>&1
if errorlevel 1 goto missing_tools
where node >nul 2>&1
if errorlevel 1 goto missing_tools
where npm >nul 2>&1
if errorlevel 1 goto missing_tools
node -e "const [major,minor]=process.versions.node.split('.').map(Number); if (!(major===22&&minor>=12 || major>=24)) { console.error('Use Node.js 22.12+ or 24+.'); process.exit(1); }"
if errorlevel 1 exit /b 1
rem Choose free ports automatically, including when AirPlay or another app owns 5000.
set "backend_port="
set "frontend_port="
for /l %%P in (5000,1,5010) do call :pick_backend %%P
for /l %%P in (5173,1,5183) do call :pick_frontend %%P
if not defined backend_port goto port_busy
if not defined frontend_port goto port_busy
set "BackendUrl=http://localhost:%backend_port%"
set "VITE_API_BASE_URL=%BackendUrl%/api"
echo Backend: %BackendUrl%
echo Frontend: http://localhost:%frontend_port%

rem Explicit overrides can point to remote SQL Server; leave local Docker untouched.
if defined ConnectionStrings__DefaultConnection goto dependencies
call :port_open 1433
if not errorlevel 1 goto local_password

rem Prefer installed Windows SQL Server options when TCP SQL Server is unavailable.
where sqllocaldb >nul 2>&1
if errorlevel 1 goto express
sqllocaldb info MSSQLLocalDB >nul 2>&1
if not errorlevel 1 goto start_localdb
rem A fresh LocalDB installation may not have created its default instance yet.
sqllocaldb create MSSQLLocalDB >nul 2>&1
if errorlevel 1 goto express
:start_localdb
echo Starting Windows LocalDB...
sqllocaldb start MSSQLLocalDB >nul 2>&1
if not errorlevel 1 goto dependencies
:express
powershell -NoProfile -Command "if ((Get-Service -Name 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue).Status -eq 'Running') { exit 0 } else { exit 1 }"
if not errorlevel 1 goto dependencies

rem A Docker volume keeps physical database files out of the project repository.
where docker >nul 2>&1
if errorlevel 1 goto missing_sql
docker info >nul 2>&1
if errorlevel 1 goto missing_sql
if not defined MSSQL_SA_PASSWORD set "MSSQL_SA_PASSWORD=Cinema560!LocalDemo2026"
docker container inspect cis560-movie-booking-sql >nul 2>&1
if errorlevel 1 goto create_container
echo Starting the existing project SQL Server container...
docker start cis560-movie-booking-sql >nul
if errorlevel 1 exit /b 1
goto local_password
:create_container
echo Creating SQL Server 2022 Developer; the first image download may take a few minutes...
docker run --detach --name cis560-movie-booking-sql --platform linux/amd64 --publish 127.0.0.1:1433:1433 --env ACCEPT_EULA=Y --env MSSQL_PID=Developer --env "MSSQL_SA_PASSWORD=%MSSQL_SA_PASSWORD%" --volume cis560-movie-booking-data:/var/opt/mssql mcr.microsoft.com/mssql/server:2022-latest >nul
if errorlevel 1 exit /b 1
:local_password
if defined MSSQL_SA_PASSWORD set "ConnectionStrings__DefaultConnection=Server=localhost,1433;Database=MovieTheaterBooking;User Id=sa;Password=%MSSQL_SA_PASSWORD%;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5;"

:dependencies
rem Install exact lockfile versions only when the first clone has no node_modules.
if exist Frontend\node_modules goto launch
call npm ci --prefix Frontend
if errorlevel 1 exit /b 1
:launch
echo Starting backend; first launch creates and seeds the database automatically...
start "CIS 560 Backend - Ctrl+C to stop" /D "%~dp0" cmd /k dotnet run --project Backend/Backend.csproj
rem Wait for SQL setup before launching the frontend; leave a failed backend window visible for diagnosis.
powershell -NoProfile -Command "$ready=$false; for ($i=0; $i -lt 120; $i++) { try { $r=Invoke-WebRequest -UseBasicParsing '%BackendUrl%/swagger/index.html' -TimeoutSec 1; if ($r.StatusCode -eq 200) { $ready=$true; break } } catch {}; Start-Sleep -Seconds 1 }; if (-not $ready) { Write-Host 'Backend did not become ready. Check its console for the SQL setup message.'; exit 1 }"
if errorlevel 1 exit /b 1
start "CIS 560 Frontend - Ctrl+C to stop" /D "%~dp0Frontend" cmd /k npm run dev -- --port %frontend_port%
echo Open http://localhost:%frontend_port% or %BackendUrl%/swagger
echo Stop each app with Ctrl+C in its window. SQL Server and its volume are retained.
exit /b 0

:pick_backend
if defined backend_port exit /b 0
call :port_open %1
if errorlevel 1 set "backend_port=%1"
exit /b 0
:pick_frontend
if defined frontend_port exit /b 0
call :port_open %1
if errorlevel 1 set "frontend_port=%1"
exit /b 0

:port_open
rem Node supplies a portable TCP check without installing an extra command-line tool.
node -e "const s=require('node:net').createConnection({host:'127.0.0.1',port:Number(process.argv[1])}); s.setTimeout(1000); s.on('connect',()=>{s.destroy();process.exit(0)}); s.on('error',()=>process.exit(1)); s.on('timeout',()=>{s.destroy();process.exit(1)});" %1
exit /b %errorlevel%
:missing_tools
echo Install .NET SDK 8+ and Node.js 22.12+ or 24+, then run start.bat again.
exit /b 1
:missing_sql
echo SQL Server was not found. Start Docker Desktop, install Windows LocalDB/SQL Express,
echo or set ConnectionStrings__DefaultConnection to a working SQL Server login.
exit /b 1
:port_busy
echo No free backend port in 5000-5010 or frontend port in 5173-5183. Stop another app and try again.
exit /b 1
