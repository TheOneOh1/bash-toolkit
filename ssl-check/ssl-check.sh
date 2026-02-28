#!/bin/bash
# Check SSL certificate expiry for a list of domains

# Check if a domain list file was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-domains-file>"
    echo "Example: $0 domains.txt"
    exit 1
fi

DOMAIN_FILE=$1

# Ensure the file exists
if [ ! -f "$DOMAIN_FILE" ]; then
    echo "Error: File '$DOMAIN_FILE' not found."
    exit 1
fi

# Get the current date in epoch seconds for calculations
CURRENT_EPOCH=$(date +%s)

# Print the table header
printf "%-30s | %-15s | %s\n" "Domain" "Days Remaining" "Expiry Date"
printf "%s\n" "------------------------------------------------------------------------"


while IFS= read -r domain; do

    [[ -z "$domain" || "$domain" =~ ^# ]] && continue

    # Fetch the raw 'notAfter' date string using openssl
    RAW_EXPIRY=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

    # Handle cases where the domain is invalid or cert cannot be fetched
    if [ -z "$RAW_EXPIRY" ]; then
        printf "%-30s | %-15s | %s\n" "$domain" "ERROR" "Failed to fetch certificate"
        continue
    fi

    EXPIRY_EPOCH=$(date -d "$RAW_EXPIRY" +%s 2>/dev/null)

    # Calculate the days remaining
    DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

    printf "%-30s | %-15s | %s\n" "$domain" "$DAYS_LEFT" "$RAW_EXPIRY"

done < "$DOMAIN_FILE"
