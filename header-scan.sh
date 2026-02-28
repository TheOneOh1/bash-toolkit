#!/usr/bin/env bash

# ==============================================================================
# Script: header-scan.sh
# Description: Scans a target URL for baseline HTTP security headers.
# Usage: ./header-scan.sh <https://example.com>
# ==============================================================================

# ANSI Color Codes for CLI output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TARGET=$1

# Input Validation
if [ -z "$TARGET" ]; then
    echo -e "${RED}Error: Target URL missing.${NC}"
    echo -e "Usage: $0 <https://example.com>"
    exit 1
fi

echo -e "${BLUE}[*] Scanning target: ${TARGET}${NC}"
echo -e "${BLUE}[*] Following redirects enabled...${NC}\n"

# Fetch headers
# -s: Silent mode (no progress bar)
# -L: Follow redirects
# -D -: Dump headers to stdout
# -o /dev/null: Discard the actual page body
HEADERS=$(curl -s -L -D - -o /dev/null "$TARGET" | tr -d '\r')

# Check if curl succeeded in fetching anything
if [ -z "$HEADERS" ]; then
    echo -e "${RED}[!] Failed to retrieve headers. Check the URL and your connection.${NC}"
    exit 1
fi

# Array of baseline security headers to check
SECURITY_HEADERS=(
    "Strict-Transport-Security"
    "Content-Security-Policy"
    "X-Frame-Options"
    "X-Content-Type-Options"
    "Referrer-Policy"
    "Permissions-Policy"
)

# Print Table Header
printf "%-30s | %-10s | %s\n" "HEADER" "STATUS" "VALUE (Truncated)"
printf "%-30s | %-10s | %s\n" "------------------------------" "----------" "----------------------------------------"

# Loop through our baseline list and check against fetched headers
for HEADER in "${SECURITY_HEADERS[@]}"; do
    # Extract the header value (case-insensitive matching for robust parsing)
    VALUE=$(echo "$HEADERS" | grep -i "^${HEADER}:" | sed -E "s/^${HEADER}:[[:space:]]*//I")

    if [ -n "$VALUE" ]; then
        # Truncate value if it's too long for the CLI table (e.g., CSPs can be massive)
        SHORT_VALUE="${VALUE:0:50}"
        if [ ${#VALUE} -gt 50 ]; then
            SHORT_VALUE="${SHORT_VALUE}..."
        fi
        printf "%-30s | ${GREEN}%-10s${NC} | %s\n" "$HEADER" "Pass" "$SHORT_VALUE"
    else
        printf "%-30s | ${RED}%-10s${NC} | %s\n" "$HEADER" "Missing" "-"
    fi
done

echo -e "\n${YELLOW}[i] Note: This script verifies the presence of headers, not necessarily the security of their configured values.${NC}"