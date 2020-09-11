#!/bin/bash

TID="$CYLANCE_TID" # Cylance Tenant ID
APP_ID="$CYLANCE_APP_ID"
APP_SECRET="$CYLANCE_APP_SECRET"
REGION="$CYLANCE_REGION"

API_HOST="https://protectapi${REGION}.cylance.com"
AUTH_URL="${API_HOST}/auth/v2/token"
JTI_VAL=$(uuidgen)
TIMEOUT=1800
EPOCH_TIME=$(date +%s)
EPOCH_TIMEOUT=$(expr "$EPOCH_TIME" + "$TIMEOUT")

HEADER=$(echo -n '{"typ":"JWT","alg":"HS256"}' | /bin/base64 -w 0 | sed 's/+/-/g; s/\//_/g ; s/=\+$//g')

PAYLOAD=$(jq -n -c -r \
            --argjson exp "$EPOCH_TIMEOUT" \
            --argjson iat "$EPOCH_TIME" \
            --arg iss "http://cylance.com" \
            --arg sub "$APP_ID" \
            --arg tid "$TID" \
            --arg jti "$JTI_VAL" \
            '{"exp": $exp,"iat": $iat,"iss": $iss,"sub": $sub,"tid": $tid,"jti": $jti}' \
            | base64 -w 0 | sed 's/+/-/g; s/\//_/g; s/=\+$//g' )

SIGNATURE=$(echo -n "${HEADER}"."${PAYLOAD}" | openssl dgst -sha256 -hmac "${APP_SECRET}" -binary | openssl base64 -e -A | sed 's/+/-/g; s/\//_/g; s/=\+$//g')

TOKEN="${HEADER}.${PAYLOAD}.${SIGNATURE}"

CYLANCE_AUTH_TOKEN=$(jq -n -c \
                      --arg auth_token "$TOKEN" \
                      '{"auth_token": $auth_token}')

BEARER=$(curl -vv -s -X POST -H 'Content-Type: application/json; charset=utf-8' "$AUTH_URL" -d "$CYLANCE_AUTH_TOKEN" | jq -r .access_token)

# Example fetching some Device records from Cylance Protect API
PAGE=$(curl -s --location --request GET "${API_HOST}/devices/v2?page=1&page_size=200" \
  --header 'Accept: application/json' \
  --header "Authorization: Bearer ${BEARER}")
