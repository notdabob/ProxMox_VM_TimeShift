#!/bin/sh
# health-monitor.sh - health-monitor script to replace the command section in health-monitor of docker-compose.yaml
# NOTE: gets copied by deploy-stack.sh in the remote deployment function -- prepare_remote_deployment()
# TODO: this should be moved to a more appropriate named location (also must update deploy-stack.sh where it prepares remote deployment)

# Install needed tools
apk add --no-cache curl jq docker-cli

# Ensure output directory exists
mkdir -p /app/data

# Main monitoring loop
while true; do
  timestamp=$(date -Iseconds)
  health_checks="["
  first=true

  jq -r '.services[]' /app/config/network-services.json | while IFS= read -r service; do
    if [ -n "$service" ] && docker inspect "$service" >/dev/null 2>&1; then
      health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "unknown")
      entry="{\"service\":\"$service\",\"status\":\"$health\",\"timestamp\":\"$timestamp\"}"
      if [ "$first" = true ]; then
        first=false
      else
        health_checks="$health_checks,"
      fi
      health_checks="$health_checks$entry"
    fi
  done

  echo "{\"timestamp\":\"$timestamp\",\"health_checks\":[$health_checks]}" > /app/data/health.json
  sleep 15
done
