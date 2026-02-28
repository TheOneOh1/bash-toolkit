#!/bin/bash

# Check if a directory is provided, else use current directory
DIR="${1:-.}"

# Check if the directory exists
if [[ ! -d "$DIR" ]]; then
    echo "Error: Directory '$DIR' does not exist."
    exit 1
fi

# Analyze disk usage (only top-level items)
echo -e "================================================"
echo -e "🔍 Scanning directory: $DIR"
echo -e "================================================"
du -sh "$DIR"/* 2>/dev/null | sort -rh | awk '{ if(NR==1) { print "Disk Usage Report" } printf "%-10s %s\n", $1, $2 }' | column -t


echo -e "\nAnalysis complete!"
echo -e "================================================"
