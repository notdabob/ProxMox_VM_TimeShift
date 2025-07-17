#!/bin/sh
# service-discovery.sh - service-discovery script to replace the command section in service-discovery of docker-compose.yaml
# NOTE: gets copied by deploy-stack.sh in the remote deployment function -- prepare_remote_deployment()
# TODO: this should be moved to a more appropriate named location (also must update deploy-stack.sh where it prepares remote deployment)

# Install needed tools
apk add --no-cache curl jq docker-cli

# Ensure output directory exists
# ?? should this be refactored to /app/data to be more consistent with health-monitor.sh
mkdir -p /app/registry

# Main monitoring loop
while true; do
  docker ps --format '{{json .}}' | jq -s '{
    timestamp: now | todate,
    services: map({
      name: .Names,
      image: .Image,
      port: .Ports,
      status: .Status,
      labels: (.Labels | split(",") | map(split("=") | {(.[0]): .[1]}) | add)
    })
  }'
  sleep 30
done
