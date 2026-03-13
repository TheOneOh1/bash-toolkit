#!/bin/bash

SERVICE_NAME=$1
PORT=$2
HOST=${3:-localhost}
HOSTNAME=$(hostname)

TIMEOUT=5
MAX_RETRIES=5
SLEEP_INTERVAL=3

URL="http://$HOST:$PORT/actuator/health"

echo "----------------------------------------"
echo "Checking Service Health..."
echo "----------------------------------------"

echo "Checking health for $SERVICE_NAME"
echo "Endpoint: $URL"
echo "Deploying on $HOSTNAME"
echo "----------------------------------------"

attempt=1

while [ $attempt -le $MAX_RETRIES ]; do

    # ===== PORT CHECK =====
    if ss -lnt | grep -q ":8085 "; then
#    if ! nc -z "$HOST" "$PORT" >/dev/null 2>&1; then
        echo "STATUS: PORT $PORT is LISTENING"
    else
        echo "STATUS: PORT $PORT NOT LISTENING"
        echo "Attempt $attempt/$MAX_RETRIES"
        sleep $SLEEP_INTERVAL
        ((attempt++))
        continue
    fi

    # ===== ACTUATOR CHECK =====
    RESPONSE=$(curl -s --max-time $TIMEOUT -w "HTTPSTATUS:%{http_code}" "$URL")

    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS\:.*//g')
    STATUS=$(echo "$RESPONSE" | tr -d '\n' | sed 's/.*HTTPSTATUS://')

    if [[ "$STATUS" == "200" ]] && echo "$BODY" | grep -q '"status":"UP"'; then
        echo "STATUS: UP"
        echo "----------------------------------------"
        exit 0
    fi

    if [[ "$STATUS" == "404" ]]; then
        echo "STATUS: SERVICE RUNNING BUT /actuator/health NOT EXPOSED"
        echo "----------------------------------------"
        exit 2
    fi

    echo "STATUS: HTTP ERROR ($STATUS)"
    echo "Attempt $attempt/$MAX_RETRIES"
    echo "----------------------------------------"

    sleep $SLEEP_INTERVAL
    ((attempt++))

done

echo "FINAL RESULT: HEALTH CHECK FAILED"
echo "----------------------------------------"
#echo "Last HTTP Code: $STATUS"
#echo "Response: $BODY"

exit 1