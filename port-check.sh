#!/bin/bash

detect_tool() {
    printf "Checking for ss dependency...\n"
    if command -v ss >/dev/null 2>&1; then
        printf "Using: ss\n"
    else
        printf "Error: ss is not installed.\n"
        exit 1
    fi
}

print_header() {
    echo -e "================================================"
    echo -e "               OCCUPIED PORTS"
    echo -e "================================================"
}

port_check(){
    ss -tunlp 2>/dev/null | awk 'NR>1 { split($5, addr, ":"); proc=$7; gsub(/.*\(\("/, "", proc); gsub(/".*/, "", proc); print "State: " $2 " | Port: " addr[length(addr)] " | Process: " proc }'
    echo -e "================================================"
}

detect_tool
print_header
port_check
