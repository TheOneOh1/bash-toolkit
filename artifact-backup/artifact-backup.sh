#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ==============================
# Global Configuration
# ==============================

readonly BACKUP_ROOT="/opt/artifact-backups"
readonly RETENTION_COUNT=5

readonly ARTIFACTS=(
  "/opt/java-services/scheduler-service/pay-status-scheduler.war"
  "/opt/java-services/auth-service/pas-auth-service.jar"
  "/opt/java-services/pas-service/pas-service.war"
  "/opt/java-services/lookup-service/lookup-service.war"
  "/opt/java-services/user-detail-service/pas-user-details.war"
  "/opt/java-services/payment-service/payment-service.war"
)

# ==============================
# Logging Functions
# ==============================

log_info() {
  local message="$1"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [INFO] ${message}"
}

log_error() {
  local message="$1"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [ERROR] ${message}" >&2
}

# ==============================
# Cleanup Handler
# ==============================

cleanup() {
  log_info "Backup script finished"
}

trap cleanup EXIT SIGINT SIGTERM

# ==============================
# Utility Functions
# ==============================

ensure_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
  fi
}

ensure_backup_root() {
  if [[ ! -d "${BACKUP_ROOT}" ]]; then
    log_info "Creating backup root directory ${BACKUP_ROOT}"
    mkdir -p "${BACKUP_ROOT}"
  fi
}

timestamp() {
  date +"%Y%m%d_%H%M%S"
}

cleanup_old_backups() {
  local service_dir="$1"
  local artifact_name="$2"

  mapfile -t backups < <(
    ls -1t "${service_dir}/${artifact_name}"_* 2>/dev/null || true
  )

  if (( ${#backups[@]} > RETENTION_COUNT )); then
    for ((i=RETENTION_COUNT; i<${#backups[@]}; i++)); do
      log_info "Removing old backup ${backups[$i]}"
      rm -f "${backups[$i]}"
    done
  fi
}

backup_artifact() {
  local artifact_path="$1"

  if [[ ! -f "${artifact_path}" ]]; then
    log_error "Artifact not found: ${artifact_path}"
    exit 1
  fi

  local artifact_file
  artifact_file="$(basename "${artifact_path}")"

  local artifact_name
  artifact_name="${artifact_file%.*}"

  local extension
  extension="${artifact_file##*.}"

  local service_name
  service_name="$(basename "$(dirname "${artifact_path}")")"

  local service_backup_dir="${BACKUP_ROOT}/${service_name}"

  mkdir -p "${service_backup_dir}"

  local ts
  ts="$(timestamp)"

  local backup_file="${service_backup_dir}/${artifact_name}_${ts}.${extension}"

  log_info "Backing up ${artifact_file}"
  cp "${artifact_path}" "${backup_file}"

  log_info "Backup created: ${backup_file}"

  cleanup_old_backups "${service_backup_dir}" "${artifact_name}"
}

# ==============================
# Main
# ==============================

main() {

  ensure_root
  ensure_backup_root

  log_info "Starting artifact backup"

  for artifact in "${ARTIFACTS[@]}"; do
    backup_artifact "${artifact}"
  done

  log_info "All artifacts backed up successfully"
}

main "$@"