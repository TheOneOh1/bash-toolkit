#!/bin/bash

# --- Configuration & Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

echo -e "${YELLOW}=== Nginx Hardening Compliance Report ===${NC}"
echo "Generated on: $(date)"
echo "---------------------------------------"

# Get the full effective config (requires sudo)
CONF_DUMP=$(sudo nginx -T 2>/dev/null)

if [[ -z "$CONF_DUMP" ]]; then
    echo -e "${RED}[ERROR] Could not read Nginx config. Are you root? Is Nginx installed?${NC}"
    exit 1
fi

check_nginx_setting() {
    local label=$1
    local regex=$2
    local expected_msg=$3

    if echo "$CONF_DUMP" | grep -qE "$regex"; then
        printf "%-25s [%bPASS%b] %s\n" "$label" "$GREEN" "$NC" "$expected_msg"
    else
        printf "%-25s [%bFAIL%b] Missing or misconfigured\n" "$label" "$RED" "$NC"
    fi
}

# --- 1. Information Leakage ---
# Ensure version number is hidden in error pages/headers
check_nginx_setting "Server Tokens" "server_tokens off;" "Version hidden"

# --- 2. SSL/TLS Strength ---
# Check if TLS 1.0/1.1 are disabled (Modern: 1.2 and 1.3 only)
if echo "$CONF_DUMP" | grep "ssl_protocols" | grep -qvE "TLSv1.2|TLSv1.3"; then
    printf "%-25s [%bFAIL%b] Legacy TLS (1.0/1.1) detected!\n" "SSL Protocols" "$RED" "$NC"
else
    printf "%-25s [%bPASS%b] Modern TLS Only (1.2/1.3)\n" "SSL Protocols" "$GREEN" "$NC"
fi

# --- 3. Security Headers ---
check_nginx_setting "HSTS Header" "add_header Strict-Transport-Security" "Enforced"
check_nginx_setting "X-Frame-Options" "add_header X-Frame-Options (SAMEORIGIN|DENY)" "Clickjacking protection on"
check_nginx_setting "X-Content-Type" "add_header X-Content-Type-Options nosniff" "MIME sniffing disabled"

# --- 4. Buffer Overflow Protection ---
check_nginx_setting "Client Body Limit" "client_max_body_size" "Set (Prevents large uploads)"

echo "---------------------------------------"