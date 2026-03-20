#!/bin/bash

set -e

RESOURCE_GROUP="${1:-}"
CONTAINER_APP_NAME="${2:-}"

if [ -z "$RESOURCE_GROUP" ] || [ -z "$CONTAINER_APP_NAME" ]; then
  echo "Usage: ./scripts/health-check.sh <resource_group> <container_app_name>"
  echo ""
  echo "Example:"
  echo "  ./scripts/health-check.sh rg-azure-chatbot-prod my-container-app"
  exit 1
fi

echo "Fetching FQDN for Container App: $CONTAINER_APP_NAME in resource group: $RESOURCE_GROUP..."
FQDN=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" -o tsv)

if [ -z "$FQDN" ]; then
  echo "Error: Could not retrieve FQDN for container app. Check your resource group and container app name."
  exit 1
fi

echo "Running health check on https://$FQDN..."
for i in $(seq 1 30); do
  HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "https://$FQDN/" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" -ge "200" ] && [ "$HTTP_CODE" -lt "500" ]; then
    echo "✓ Backend is responding (HTTP $HTTP_CODE)"
    exit 0
  fi
  echo "Attempt $i/30 - HTTP $HTTP_CODE, waiting 10s..."
  sleep 10
done
echo "⚠ Backend health check timed out after 5 minutes"
exit 1
