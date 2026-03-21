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
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
SCAN_DIR=""
TOTAL_FINDINGS=0
FILES_SCANNED=0
FILES_WITH_HITS=0

# ==============================
# Secret Patterns
#
# Each pattern is a label + regex pair separated by "::".
# These cover the most commonly leaked secrets.
# Not exhaustive, but catches the usual suspects.
# ==============================
PATTERNS=(
    "AWS Access Key ID::AKIA[0-9A-Z]{16}"
    "AWS Secret Access Key::['\"]?[0-9a-zA-Z/+=]{40}['\"]?"
    "Private Key Block::-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
    "GitHub Token::gh[posru]_[A-Za-z0-9_]{36,}"
    "Generic API Key::[aA][pP][iI][-_]?[kK][eE][yY]\s*[=:]\s*['\"]?[A-Za-z0-9_\-]{16,}['\"]?"
    "Bearer Token::[bB]earer\s+[A-Za-z0-9\-._~+/]+=*"
    "Slack Token::xox[bposa]-[0-9A-Za-z\-]{10,}"
    "Password Assignment::(password|passwd|pwd)\s*[=:]\s*['\"]?[^\s'\"]{4,}['\"]?"
    "Secret Assignment::(secret|SECRET)\s*[=:]\s*['\"]?[^\s'\"]{4,}['\"]?"
    "Token Assignment::(token|TOKEN)\s*[=:]\s*['\"]?[^\s'\"]{8,}['\"]?"
    "Private Key (PEM)::-----BEGIN CERTIFICATE-----"
    "Hardcoded IP with Port::[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{2,5}"
    "Heroku API Key::[hH]eroku.*[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
    "Generic Secret in .env::^[A-Z_]+SECRET[A-Z_]*\s*=\s*.+"
    "Generic Key in .env::^[A-Z_]+KEY[A-Z_]*\s*=\s*.+"
    "Database URL::(?i)(mysql|postgres|mongodb|redis|amqp)://[^\s'\"]+"
)

# ==============================
# Usage / Help
# ==============================
usage() {
cat << EOF
${SCRIPT_NAME} v${VERSION}

Recursively scans a directory for common secret patterns — AWS keys,
Bearer tokens, private keys, .env literals, and more.

Usage:
  ${SCRIPT_NAME} --dir <path> [options]

Options:
  --dir <path>      Directory to scan (Required)
  -h, --help        Show this help

Examples:
  ${SCRIPT_NAME} --dir /home/user/myproject
  ${SCRIPT_NAME} --dir .

What it looks for:
  • AWS Access Key IDs and Secret Keys
  • GitHub / Slack / Heroku tokens
  • Bearer tokens
  • Private key blocks (PEM)
  • Hardcoded passwords, secrets, tokens
  • Database connection strings
  • .env-style KEY=value secrets
EOF
}

# ==============================
# Dependency Checks
# ==============================
require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "'$1' is required but not installed."
        exit 3
    }
}

# ==============================
# The actual scanning logic
# ==============================
scan_file() {
    local file="$1"
    local file_hits=0

    # Skip binary files — grep will choke on them anyway
    if file "$file" | grep -qE 'executable|binary|ELF|archive|image|font'; then
        return
    fi

    for entry in "${PATTERNS[@]}"; do
        local label="${entry%%::*}"
        local pattern="${entry##*::}"

        # Use grep -Pn for Perl regex support + line numbers
        # We intentionally let this fail silently if no match
        local matches
        if matches=$(grep -Pn "$pattern" "$file" 2>/dev/null); then
            while IFS= read -r match_line; do
                if (( file_hits == 0 )); then
                    echo ""
                    echo -e "  ${BOLD}${CYAN}📄 ${file}${NC}"
                    echo -e "  ${DIM}$(printf '%.0s─' {1..60})${NC}"
                fi
                file_hits=$((file_hits + 1))

                local line_num="${match_line%%:*}"
                local line_content="${match_line#*:}"

                # Trim whitespace on the content for cleaner output
                line_content="$(echo "$line_content" | sed 's/^[[:space:]]*//' | cut -c1-120)"

                echo -e "  ${YELLOW}⚠  ${label}${NC}"
                echo -e "     ${DIM}Line ${line_num}:${NC} ${line_content}"
                echo ""

            done <<< "$matches"
        fi
    done

    FILES_SCANNED=$((FILES_SCANNED + 1))

    if (( file_hits > 0 )); then
        TOTAL_FINDINGS=$((TOTAL_FINDINGS + file_hits))
        FILES_WITH_HITS=$((FILES_WITH_HITS + 1))
    fi
}

run_scan() {
    local target_dir="$1"

    echo ""
    echo "========================================"
    echo " Secret Scan Started"
    echo "========================================"
    echo ""
    log_info "Target      : ${target_dir}"
    log_info "Patterns    : ${#PATTERNS[@]} rules loaded"
    echo ""
    echo -e "  ${DIM}Scanning files recursively...${NC}"

    # Walk through every file in the directory
    while IFS= read -r -d '' file; do
        scan_file "$file"
    done < <(find "$target_dir" -type f -print0 2>/dev/null)

    # Final summary
    echo ""
    echo "========================================"
    echo " Scan Complete"
    echo "========================================"
    echo ""
    log_info "Files scanned   : ${FILES_SCANNED}"

    if (( TOTAL_FINDINGS > 0 )); then
        log_warn "Findings        : ${TOTAL_FINDINGS} potential secret(s) in ${FILES_WITH_HITS} file(s)"
        echo ""
        echo -e "  ${RED}${BOLD}⚠  Review the findings above and rotate any exposed secrets.${NC}"
        echo ""
        exit 1
    else
        log_success "No secrets found — looking clean 👍"
        echo ""
        exit 0
    fi
}

# ==============================
# Argument Parsing
# ==============================
[[ $# -eq 0 ]] && usage && exit 2

while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;

        --dir)
            [[ -z "${2:-}" ]] && { log_error "--dir requires a path argument"; exit 2; }
            SCAN_DIR="$2"
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
    [[ -z "$SCAN_DIR" ]] && {
        log_error "--dir is required"
        usage
        exit 2
    }

    [[ ! -d "$SCAN_DIR" ]] && {
        log_error "Directory '$SCAN_DIR' does not exist"
        exit 1
    }

    require_command grep
    require_command find
    require_command file
    require_command sed

    run_scan "$SCAN_DIR"
}

main "$@"
