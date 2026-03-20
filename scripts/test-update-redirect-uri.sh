#!/bin/bash
set -euo pipefail

# Test script for updating SPA redirect URIs
# Usage: ./test-update-redirect-uri.sh <app-client-id> <redirect-uri>

APP_CLIENT_ID="${1:-9efdd887-0057-4f48-846e-cc5685e3d9e8}"
REDIRECT_URI="${2:-http://test.com}"

echo "=== Step 1: Fetching current URIs ==="
CURRENT_URIS=$(az ad app show \
  --id "$APP_CLIENT_ID" \
  --query "spa.redirectUris" -o json)

echo "Current SPA redirect URIs: $CURRENT_URIS"

echo "=== Step 2: Checking if URI already exists ==="
if echo "$CURRENT_URIS" | grep -qF "$REDIRECT_URI"; then
  echo "Redirect URI already exists. No update needed."
  exit 0
fi

echo "URI not found, will add: $REDIRECT_URI"

echo "=== Step 3: Building URI list ==="
if [ "$CURRENT_URIS" = "null" ] || [ "$CURRENT_URIS" = "[]" ]; then
  REDIRECT_URIS_JSON=$(printf '["%s"]' "$REDIRECT_URI")
else
  REDIRECT_URIS_JSON=$(echo "$CURRENT_URIS" | jq -c --arg uri "$REDIRECT_URI" '. + [$uri]')
fi

echo "DEBUG: REDIRECT_URIS_JSON=$REDIRECT_URIS_JSON"

echo "=== Step 4: Running az rest to update SPA redirect URIs ==="
BODY="{\"spa\":{\"redirectUris\":$REDIRECT_URIS_JSON}}"
echo "DEBUG BODY: $BODY"

az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='$APP_CLIENT_ID')" \
  --headers "Content-Type=application/json" \
  --body "$BODY"

echo "=== Step 6: Verifying update ==="
UPDATED_URIS=$(az ad app show \
  --id "$APP_CLIENT_ID" \
  --query "spa.redirectUris" -o json)

echo "Updated SPA redirect URIs: $UPDATED_URIS"
echo "✅ Done"
