#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================
# Constants
# ==============================
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# ==============================
# Colors
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================
# Logging Functions
# ==============================
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ==============================
# Error Handler
# ==============================
error_handler() {
    log_error "Error on line $1"
    exit 1
}
trap 'error_handler $LINENO' ERR

# ==============================
# Default Configuration
# ==============================
LOG_PATH=""
MAX_SIZE_MB=30
MAX_AGE_DAYS=30
ARCHIVE_DIR=""

# ==============================
# Core Logic
# ==============================

usage() {
cat << EOF
${SCRIPT_NAME} v${VERSION}

Smart log rotation and compression for application logs.
Handles size limits, max age, and archiving to a configurable directory.

Usage:
  ${SCRIPT_NAME} --log-path <path> [options]

Options:
  --log-path <path>     Target log file or directory (Required)
  --max-size <MB>       Max size in megabytes before rotation (Default: ${MAX_SIZE_MB})
  --max-age <days>      Max age in days before old logs are archived (Default: ${MAX_AGE_DAYS})
  --archive-dir <path>  Directory to move archived logs (Default: <log-path-dir>/archive)
  -h, --help            Show help
  -v, --version         Show version

Examples:
  # Rotate a specific log file
  ${SCRIPT_NAME} --log-path /var/log/myapp/app.log

  # Rotate all .log files in a directory with custom limits
  ${SCRIPT_NAME} --log-path /var/log/myapp --max-size 50 --max-age 14

Cron Job Setup Example:
  # Run daily at 2:00 AM (Ensure absolute paths are used in cron)
  0 2 * * * /path/to/log-rotate.sh --log-path /var/log/myapp >> /var/log/log-rotate-script.log 2>&1
EOF
}

# -----------------------------
# Dependency Checks
# -----------------------------
require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "$1 is required but not installed"
        exit 1
    }
}

# -----------------------------
# Rotation Implementation
# -----------------------------
rotate_file() {
    local file="$1"
    local size_mb="$2"
    local current_size_bytes

    current_size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
    local current_size_mb=$((current_size_bytes / 1024 / 1024))

    if (( current_size_mb >= size_mb )); then
        log_info "Rotating '$file' (Size: ${current_size_mb}MB >= ${size_mb}MB)"
        
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        local rotated_file="${file}.${timestamp}"
        
        # Copy and truncate to be safe with actively running apps
        cp "$file" "$rotated_file"
        > "$file"
        
        # Compress the rotated log
        gzip "$rotated_file"
        log_success "Rotated and compressed to ${rotated_file}.gz"
    fi
}

# -----------------------------
# Archiving Implementation
# -----------------------------
archive_old_logs() {
    local target_dir="$1"
    local archive_dir="$2"
    local max_age="$3"
    
    [[ ! -d "$archive_dir" ]] && {
        mkdir -p "$archive_dir"
        log_info "Created archive directory at '$archive_dir'"
    }

    log_info "Searching for compressed logs older than $max_age days in '$target_dir'..."
    
    # Process find results carefully using while read
    while IFS= read -r -d '' old_log; do
        if [[ -n "$old_log" ]]; then
            local base_old_log
            base_old_log=$(basename "$old_log")
            mv "$old_log" "${archive_dir}/${base_old_log}"
            log_success "Archived $base_old_log to '$archive_dir'"
        fi
    done < <(find "$target_dir" -maxdepth 1 -name "*.gz" -type f -mtime +"${max_age}" -print0)
}

# ==============================
# Argument Parsing
# ==============================

[[ $# -eq 0 ]] && usage && exit 1

while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "$VERSION"
            exit 0
            ;;
        --log-path)
            [[ -z "${2:-}" ]] && { log_error "--log-path requires an argument"; exit 1; }
            LOG_PATH="$2"
            shift 2
            ;;
        --max-size)
            [[ -z "${2:-}" ]] && { log_error "--max-size requires an argument"; exit 1; }
            MAX_SIZE_MB="$2"
            shift 2
            ;;
        --max-age)
            [[ -z "${2:-}" ]] && { log_error "--max-age requires an argument"; exit 1; }
            MAX_AGE_DAYS="$2"
            shift 2
            ;;
        --archive-dir)
            [[ -z "${2:-}" ]] && { log_error "--archive-dir requires an argument"; exit 1; }
            ARCHIVE_DIR="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ==============================
# Main Execution
# ==============================

main() {
    [[ -z "$LOG_PATH" ]] && {
        log_error "--log-path is required"
        usage
        exit 1
    }
    
    [[ ! -e "$LOG_PATH" ]] && {
        log_error "Log path '$LOG_PATH' does not exist"
        exit 1
    }

    # Ensure required commands
    require_command gzip
    require_command find
    require_command stat
    require_command date
    require_command cp
    require_command mv
    require_command mkdir

    echo "========================================"
    echo " Log Rotation Started"
    echo "========================================"

    log_info "Log Path    : $LOG_PATH"
    log_info "Max Size    : ${MAX_SIZE_MB} MB"
    log_info "Max Age     : ${MAX_AGE_DAYS} days"

    local target_dir
    if [[ -d "$LOG_PATH" ]]; then
        target_dir="$LOG_PATH"
    else
        target_dir=$(dirname "$LOG_PATH")
    fi

    if [[ -z "$ARCHIVE_DIR" ]]; then
        ARCHIVE_DIR="${target_dir}/archive"
    fi
    log_info "Archive Dir : $ARCHIVE_DIR"
    echo "----------------------------------------"

    # 1. Rotate Logs
    if [[ -d "$LOG_PATH" ]]; then
        # It's a directory, rotate all .log files
        while IFS= read -r -d '' log_file; do
            [[ -n "$log_file" ]] && rotate_file "$log_file" "$MAX_SIZE_MB"
        done < <(find "$LOG_PATH" -maxdepth 1 -name "*.log" -type f -print0)
    else
        # It's a specific file
        rotate_file "$LOG_PATH" "$MAX_SIZE_MB"
    fi

    # 2. Archive Old Logs
    archive_old_logs "$target_dir" "$ARCHIVE_DIR" "$MAX_AGE_DAYS"
    
    echo "----------------------------------------"
    log_success "Log rotation completed successfully"
}

main "$@"
