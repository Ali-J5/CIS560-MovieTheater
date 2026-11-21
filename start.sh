#!/usr/bin/env bash
# Launch from any working directory; all project paths are relative to this file.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Explain missing prerequisites before starting any child processes.
for tool in dotnet node npm; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing $tool. Install .NET SDK 8+ and Node.js 22.12+ (or 24+), then run this script again."
    exit 1
  fi
done
node -e 'const [major,minor]=process.versions.node.split(".").map(Number); if (!(major===22&&minor>=12 || major>=24)) { console.error("Use Node.js 22.12+ or 24+."); process.exit(1); }'

# Node is already required, so this portable TCP probe needs no netcat or extra package.
port_open() {
  node -e 'const socket=require("node:net").createConnection({host:"127.0.0.1",port:Number(process.argv[1])}); socket.setTimeout(1000); socket.on("connect",()=>{socket.destroy();process.exit(0)}); socket.on("error",()=>process.exit(1)); socket.on("timeout",()=>{socket.destroy();process.exit(1)});' "$1"
}
# macOS AirPlay commonly owns 5000; choose nearby free ports instead of changing system settings.
choose_port() {
  local candidate
  for ((candidate=$1; candidate<=$2; candidate++)); do
    if ! port_open "$candidate"; then echo "$candidate"; return 0; fi
  done
  echo "No free port in $1-$2. Stop another local app and try again." >&2
  return 1
}
backend_port="$(choose_port 5000 5010)"
frontend_port="$(choose_port 5173 5183)"
export BackendUrl="http://localhost:$backend_port"
export VITE_API_BASE_URL="$BackendUrl/api"
echo "Backend: $BackendUrl"
echo "Frontend: http://localhost:$frontend_port"

# An explicit connection override may point to a remote server: do not start local Docker.
if [[ -z "${ConnectionStrings__DefaultConnection:-}" ]]; then
  if ! port_open 1433; then
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
      echo "SQL Server is not listening on port 1433. Start Docker Desktop and run this script again,"
      echo "or set ConnectionStrings__DefaultConnection to your existing SQL Server connection."
      exit 1
    fi
    # Keep database files in a Docker volume, outside the submission repository.
    export MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:-Frame560!d1fa85fafb28f1fcbd043aa4df1cfc5daA}"
    container="cis560-movie-booking-sql"
    if docker container inspect "$container" >/dev/null 2>&1; then
      echo "Starting the existing project SQL Server container..."
      docker start "$container" >/dev/null
    else
      echo "Creating a local SQL Server 2022 Developer container (first image download may take a few minutes)..."
      docker run --detach --name "$container" --platform linux/amd64 \
        --publish 127.0.0.1:1433:1433 \
        --env ACCEPT_EULA=Y --env MSSQL_PID=Developer \
        --env MSSQL_SA_PASSWORD="$MSSQL_SA_PASSWORD" \
        --volume cis560-movie-booking-data:/var/opt/mssql \
        mcr.microsoft.com/mssql/server:2022-latest >/dev/null
    fi
  fi
  # The public demo credential matches appsettings; a launcher override supports a custom password.
  if [[ -n "${MSSQL_SA_PASSWORD:-}" ]]; then
    export ConnectionStrings__DefaultConnection="Server=localhost,1433;Database=MovieTheaterBooking;User Id=sa;Password=$MSSQL_SA_PASSWORD;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5;"
  fi
fi

# Install the committed dependency versions on the first clone; no global Vite installation is needed.
if [[ ! -d Frontend/node_modules ]]; then
  echo "Installing frontend dependencies..."
  npm ci --prefix Frontend
fi

# Stop the launched process trees on Ctrl+C or failure; keep SQL Server/data available for next time.
backend_pid=""
frontend_pid=""
stop_tree() {
  local child
  if command -v pgrep >/dev/null 2>&1; then
    for child in $(pgrep -P "$1" || true); do stop_tree "$child"; done
  fi
  kill "$1" 2>/dev/null || true
}
cleanup() {
  trap - EXIT
  [[ -z "$frontend_pid" ]] || stop_tree "$frontend_pid"
  [[ -z "$backend_pid" ]] || stop_tree "$backend_pid"
  return 0
}
trap cleanup EXIT
trap 'exit 130' INT TERM

echo "Starting backend; first launch automatically creates and seeds the database..."
dotnet run --project Backend/Backend.csproj &
backend_pid=$!

# Wait for initialization to finish before opening the frontend, and detect backend startup failures.
ready=false
for ((attempt=1; attempt<=120; attempt++)); do
  if ! kill -0 "$backend_pid" 2>/dev/null; then
    echo "Backend setup failed. See its message above; no frontend was started."
    exit 1
  fi
  if node -e 'fetch(process.argv[1],{signal:AbortSignal.timeout(1000)}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))' "$BackendUrl/swagger/index.html"; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo "Backend did not become ready within two minutes. Check the SQL Server messages above."
  exit 1
fi

echo "Starting frontend: http://localhost:$frontend_port (API explorer: $BackendUrl/swagger)"
echo "Press Ctrl+C here to stop both apps. SQL Server and its volume are retained."
npm run dev --prefix Frontend -- --port "$frontend_port" &
frontend_pid=$!
# Bash 3 on macOS has no wait -n, so monitor both child processes explicitly.
while kill -0 "$backend_pid" 2>/dev/null && kill -0 "$frontend_pid" 2>/dev/null; do sleep 1; done
echo "An application stopped. Shutting down the other application."
exit 1
