#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================
# Constants
# ==============================
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
readonly TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"

# ==============================
# Colors (only for terminal, stripped from file output)
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
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
    log_error "Something went wrong on line $1"
    exit 1
}
trap 'error_handler $LINENO' ERR

# ==============================
# Default Configuration
# ==============================
OUTPUT_DIR="."
SNAPSHOT_FILE=""

# ==============================
# Usage / Help
# ==============================
usage() {
cat << EOF
${SCRIPT_NAME} v${VERSION}

Takes a point-in-time snapshot of the system state — CPU, memory,
top processes, disk I/O, and open file descriptors.

Handy for capturing what's going on during incidents or performance issues.

Usage:
  ${SCRIPT_NAME} [options]

Options:
  --output-dir <path>   Directory to save the snapshot file (Default: current dir)
  -h, --help            Show this help

Output:
  Prints everything to the terminal AND saves a copy to a timestamped
  file like snapshot_20260321_140000.txt in the output directory.

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --output-dir /tmp/snapshots
EOF
}

# ==============================
# Dependency Checks
# ==============================
require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log_warn "'$1' not found — skipping that section"
        return 1
    }
}

# ==============================
# Section printer
# ==============================
print_section() {
    local title="$1"
    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "  $title"
    echo "────────────────────────────────────────────────────────────"
    echo ""
}

# ==============================
# Snapshot Sections
# ==============================

snapshot_header() {
    echo ""
    echo "========================================"
    echo "  System Snapshot"
    echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "  Host: $(hostname)"
    echo "========================================"
}

snapshot_uptime() {
    print_section "Uptime & Load Average"
    uptime
}

snapshot_cpu() {
    print_section "CPU Usage"

    if [[ -f /proc/stat ]]; then
        # Quick CPU summary from /proc/stat
        local cores
        cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")
        echo "  CPU Cores: $cores"
        echo ""
    fi

    # Top-level CPU breakdown if mpstat is around
    if require_command mpstat; then
        mpstat 1 1 2>/dev/null | tail -n 2
    elif require_command top; then
        # Fallback: grab the CPU line from top
        top -bn1 | grep '%Cpu' | head -1
    else
        log_warn "Neither mpstat nor top available for CPU stats"
    fi
}

snapshot_memory() {
    print_section "Memory Usage"

    if require_command free; then
        free -h
    elif [[ -f /proc/meminfo ]]; then
        head -5 /proc/meminfo
    fi
}

snapshot_top_processes() {
    print_section "Top 20 Processes (by CPU)"

    if require_command ps; then
        printf "%-8s %-6s %-6s %s\n" "PID" "%CPU" "%MEM" "COMMAND"
        echo "----------------------------------------------"
        ps aux --sort=-%cpu 2>/dev/null \
            | awk 'NR>1 && NR<=21 {printf "%-8s %-6s %-6s %s\n", $2, $3, $4, $11}'
    fi
}

snapshot_disk_io() {
    print_section "Disk I/O"

    if require_command iostat; then
        iostat -dx 1 1 2>/dev/null | tail -n +4
    elif [[ -f /proc/diskstats ]]; then
        echo "  (iostat not available, showing raw /proc/diskstats)"
        echo ""
        printf "%-10s %-12s %-12s\n" "DEVICE" "READS" "WRITES"
        echo "----------------------------------------------"
        awk '{printf "%-10s %-12s %-12s\n", $3, $4, $8}' /proc/diskstats \
            | grep -v '       0            0' 2>/dev/null || true
    else
        log_warn "No disk I/O stats available"
    fi
}

snapshot_disk_usage() {
    print_section "Disk Usage"

    if require_command df; then
        df -h --total 2>/dev/null | grep -E '^/|^Filesystem|^total'
    fi
}

snapshot_file_descriptors() {
    print_section "Open File Descriptors"

    if [[ -f /proc/sys/fs/file-nr ]]; then
        local allocated max
        read -r allocated _ max < /proc/sys/fs/file-nr
        echo "  Allocated : $allocated"
        echo "  Max       : $max"
        echo ""

        # Quick percentage for at-a-glance severity
        if (( max > 0 )); then
            local pct=$(( (allocated * 100) / max ))
            echo "  Usage     : ${pct}%"
            if (( pct > 80 )); then
                echo "  ⚠  File descriptor usage is high!"
            fi
        fi
    else
        log_warn "/proc/sys/fs/file-nr not available"
    fi
}

snapshot_network() {
    print_section "Network Connections (summary)"

    if require_command ss; then
        echo "  State breakdown:"
        ss -s 2>/dev/null | head -5
    elif require_command netstat; then
        netstat -ant 2>/dev/null | awk '/^tcp/ {print $6}' | sort | uniq -c | sort -rn
    fi
}

# ==============================
# Run the full snapshot
# ==============================
run_snapshot() {
    SNAPSHOT_FILE="${OUTPUT_DIR}/snapshot_${TIMESTAMP}.txt"

    # Make sure the output dir exists
    [[ ! -d "$OUTPUT_DIR" ]] && {
        mkdir -p "$OUTPUT_DIR"
        log_info "Created output directory: $OUTPUT_DIR"
    }

    log_info "Capturing system snapshot..."
    echo ""

    # Tee everything to both terminal and file
    # Strip ANSI codes from the file copy using sed
    {
        snapshot_header
        snapshot_uptime
        snapshot_cpu
        snapshot_memory
        snapshot_top_processes
        snapshot_disk_io
        snapshot_disk_usage
        snapshot_file_descriptors
        snapshot_network

        echo ""
        echo "========================================"
        echo "  Snapshot Complete"
        echo "========================================"
        echo ""

    } | tee >(sed 's/\x1b\[[0-9;]*m//g' > "$SNAPSHOT_FILE")

    log_success "Snapshot saved to $SNAPSHOT_FILE"
    echo ""
}

# ==============================
# Argument Parsing
# ==============================
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        --output-dir)
            [[ -z "${2:-}" ]] && { log_error "--output-dir requires a path argument"; exit 2; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

# ==============================
# Main
# ==============================
main() {
    # Basic sanity — this is a Linux tool
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "This script is designed for Linux systems only"
        exit 1
    fi

    run_snapshot
}

main "$@"
