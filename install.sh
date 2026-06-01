#!/bin/bash

set -euo pipefail

REPO_OWNER="JasRockr"
REPO_NAME="airbyte-local-toolkit"
REPO_REF="${AIRBYTE_TOOLKIT_REF:-main}"
INSTALL_ROOT="${AIRBYTE_TOOLKIT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/airbyte-local-toolkit}"
RAW_BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}"
SETUP_URL="${RAW_BASE_URL}/airbyte-setup.sh"
MANAGEMENT_URL="${RAW_BASE_URL}/scripts/airbyte-management.sh"
TMP_ROOT=""
BACKUP_ROOT=""

log_info() {
    printf '[INFO] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

cleanup() {
    local exit_code=$?

    set +e

    if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
        rm -rf "$TMP_ROOT"
    fi

    if [ $exit_code -ne 0 ] && [ -n "$BACKUP_ROOT" ] && [ -d "$BACKUP_ROOT" ] && [ ! -e "$INSTALL_ROOT" ]; then
        mv "$BACKUP_ROOT" "$INSTALL_ROOT" >/dev/null 2>&1 || true
    elif [ -n "$BACKUP_ROOT" ] && [ -d "$BACKUP_ROOT" ]; then
        rm -rf "$BACKUP_ROOT" >/dev/null 2>&1 || true
    fi

    exit $exit_code
}

trap cleanup EXIT

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Falta el comando requerido: $1"
        exit 1
    fi
}

if [ ! -t 1 ]; then
    export NO_COLOR=1
fi

log_info "Descargando Airbyte Local Toolkit para instalación local..."
log_info "Repositorio: ${REPO_OWNER}/${REPO_NAME}@${REPO_REF}"
log_info "Destino: ${INSTALL_ROOT}"

require_command curl
require_command mkdir
require_command mv
require_command chmod

TMP_ROOT="$(mktemp -d)"
mkdir -p "$TMP_ROOT/source/scripts"

curl -fsSL "$SETUP_URL" -o "$TMP_ROOT/source/airbyte-setup.sh"
curl -fsSL "$MANAGEMENT_URL" -o "$TMP_ROOT/source/scripts/airbyte-management.sh"

chmod +x "$TMP_ROOT/source/airbyte-setup.sh" "$TMP_ROOT/source/scripts/airbyte-management.sh"

mkdir -p "$(dirname "$INSTALL_ROOT")"

if [ -e "$INSTALL_ROOT" ]; then
    BACKUP_ROOT="${INSTALL_ROOT}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$INSTALL_ROOT" "$BACKUP_ROOT"
fi

mv "$TMP_ROOT/source" "$INSTALL_ROOT"
TMP_ROOT=""

log_info "Instalación del toolkit completada. Ejecutando el setup guiado..."
cd "$INSTALL_ROOT"
exec ./airbyte-setup.sh --yes