#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"
SETTINGS_FILE="searxng/settings.yml"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 1. Verify dependencies ---
info "Verificando dependencias..."
command -v docker >/dev/null 2>&1 || error "Docker no está instalado. Instálalo primero."
docker compose version >/dev/null 2>&1 || error "'docker compose' no está disponible."
info "Docker y docker compose encontrados."

# --- 2. Create directories ---
mkdir -p searxng

# --- 3. Read port from .env ---
if [ -f "$ENV_FILE" ]; then
    PORT=$(grep -E '^SEARXNG_PORT=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
fi
PORT="${PORT:-8888}"

# --- 4. Check if port is available ---
is_port_in_use() {
    local p=$1
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | grep -q ":${p} " && return 0
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln 2>/dev/null | grep -q ":${p} " && return 0
    elif command -v lsof >/dev/null 2>&1; then
        lsof -i ":${p}" >/dev/null 2>&1 && return 0
    fi
    # Fallback: try to connect
    (echo >/dev/tcp/localhost/"$p") 2>/dev/null && return 0
    return 1
}

ORIGINAL_PORT=$PORT
while is_port_in_use "$PORT"; do
    warn "Puerto $PORT está ocupado, probando $(($PORT + 1))..."
    PORT=$(($PORT + 1))
    if [ "$PORT" -gt 65535 ]; then
        error "No se encontró un puerto disponible."
    fi
done

if [ "$PORT" != "$ORIGINAL_PORT" ]; then
    warn "Puerto cambiado de $ORIGINAL_PORT a $PORT"
fi

# Update .env with the final port
echo "SEARXNG_PORT=$PORT" > "$ENV_FILE"
info "Puerto configurado: $PORT"

# --- 5. Generate secret_key ---
if grep -q "ultrasecretkey" "$SETTINGS_FILE" 2>/dev/null; then
    SECRET_KEY=$(openssl rand -hex 32)
    sed -i "s|ultrasecretkey|${SECRET_KEY}|g" "$SETTINGS_FILE"
    info "Secret key generada."
else
    info "Secret key ya configurada."
fi

# --- 6. Start services ---
info "Levantando servicios con docker compose..."
docker compose up -d

# --- 7. Wait for SearXNG to be ready ---
info "Esperando a que SearXNG esté listo..."
MAX_WAIT=60
WAITED=0
until curl -s "http://localhost:${PORT}" >/dev/null 2>&1; do
    sleep 2
    WAITED=$((WAITED + 2))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        error "SearXNG no respondió después de ${MAX_WAIT} segundos. Revisa los logs con: docker compose logs searxng"
    fi
done

# --- 8. Show result ---
echo ""
info "========================================="
info "SearXNG está corriendo!"
info "URL: http://localhost:${PORT}"
info "========================================="
echo ""
