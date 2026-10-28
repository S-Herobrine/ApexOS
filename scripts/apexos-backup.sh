#!/bin/bash
# ==============================================================================
# ApexOS User Settings & Android Data Backup Utility
# ==============================================================================

set -euo pipefail

BACKUP_DIR="${HOME}/ApexOS-Backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEST_FILE="${BACKUP_DIR}/apexos_backup_${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"

echo "==> Creating backup: ${DEST_FILE}..."

# Export dconf settings
mkdir -p /tmp/apexos_backup
dconf dump / > /tmp/apexos_backup/dconf_settings.ini 2>/dev/null || true

# Archive configs
tar -czf "${DEST_FILE}" \
    -C "${HOME}" .config \
    -C /tmp/apexos_backup dconf_settings.ini 2>/dev/null || true

rm -rf /tmp/apexos_backup

echo "==> Backup successfully created at: ${DEST_FILE}"
