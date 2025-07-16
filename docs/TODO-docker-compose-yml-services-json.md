# TODO: URGENT: Trying to fix docker-compose.yml

- This is critical for the service discovery system as docker-compose.yml is broken and prevents the deploy-stack.sh running right
- ALSO: on proxmox host in projects folder there is additional notes in the .md file of further changes needed (URGENT, CRITICAL)

- to generate /app/registry/services.json
- docker-compose.yml in service-discovery section has annoying string interpolation errors that have been hard to resolve
- looking for a way to generate the file instead of using docker-compose.yml that would be more reliable and easier to maintain
- the docker-compose.yml is whats supposed to generate the services.json file and monitor the services to keep it updated
- but this confuses me as we also have a service-discovery shell script that does the same thing
- ALSO: yaml-lint.yml is messed up and prolly needs removed its from github actions and not needed

```bash
apt-get install -y jq
```

## Option 1: docker ps --format '{{json .}}'

```json
{
  "Command": "\"pwsh-preview\"",
  "CreatedAt": "2025-07-16 11:51:06 +0000 UTC",
  "ID": "fcd6d472a7d4",
  "Image": "mcr.microsoft.com/powershell",
  "Labels": "org.opencontainers.image.ref.name=ubuntu,org.opencontainers.image.version=22.04",
  "LocalVolumes": "0",
  "Mounts": "",
  "Names": "hardcore_poincare",
  "Networks": "bridge",
  "Ports": "",
  "RunningFor": "4 minutes ago",
  "Size": "8.04kB (virtual 339MB)",
  "State": "running",
  "Status": "Up 4 minutes"
}
```

## Option 2: simple JSON output with timestamp from docker ps

```bash
docker ps --format '{{json .}}' | jq -s '{timestamp: now | todate, services: .}' > /app/registry/services.json
```

```json
{
  "timestamp": "2025-07-16T11:57:00Z",
  "services": [
    {
      "ID": "abc123",
      "Image": "nginx",
      "Names": "web-frontend",
      ...
    },
    {
      "ID": "def456",
      "Image": "redis",
      "Names": "cache-service",
      ...
    }
  ]
}
```

## Option 3: converts labels from a string to a list of key-value pairs

```bash
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
```

```json
    "labels": {
    "homelab.service": "monitoring",
    "homelab.port": "9000"
    }
```

```json
{
  "timestamp": "2025-07-16T12:46:36Z",
  "services": [
    {
      "name": "hardcore_poincare",
      "image": "mcr.microsoft.com/powershell",
      "port": "",
      "status": "Up 55 minutes",
      "labels": {
        "org.opencontainers.image.ref.name": "ubuntu",
        "org.opencontainers.image.version": "22.04"
      }
    }
  ]
}
```

- no clue why it shows as hardcore_poincare but this is the microsoft powershell prebuilt docker image

### NOTE: alpine:latest is a secure and minimal base image

### NOTE: apk is the package manager for Alpine Linux, use the docker-cli package to get the docker command (not the full docker image as this installs the server daemon which is not needed in this case and the cli is sufficient for querying the docker host)

### NOTE: Original docker-compose.yml code snippet

- this made no sense why we called docker ps with a format to use a table and then tried to parse it as JSON
- also seemed to call echo {} after each line which wouldn't output anything useful, I **think** conceptually it was trying to wrap each service in curly braces but it was not working

```yaml
services:
  service-discovery:
      command: |
      sh -c "
        apk add --no-cache curl jq docker-cli &&
        mkdir -p /app/registry &&
        while true; do
          echo '{\"timestamp\":\"'$(date -Iseconds)'\",\"services\":[' \
            > /app/registry/services.json
          docker ps --format \
            'table {{.Names}}\t{{.Ports}}\t{{.Status}}\t{{.Labels}}' | \
            tail -n +2 | while read line; do
            echo '{},' >> /app/registry/services.json
          done
          echo ']}' >> /app/registry/services.json
          sleep 30
```
