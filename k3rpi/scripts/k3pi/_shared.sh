# Shared settings and helpers. Sourced by the other scripts in this folder,
# not run on its own.

set -euo pipefail

# repo root, two levels up from scripts/k3pi/
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$ROOT/docker-compose.yml"

# The Zot registry running on the Pi.
REGISTRY="192.168.1.187:30050"
REGISTRY_USER="admin"

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
die() { printf '\n\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }

require_docker() {
  command -v docker >/dev/null || die "docker is not installed"
  docker info >/dev/null 2>&1 || die "Docker isn't running - start Docker Desktop"
}

# docker_push <password> <service> [tag]
# Builds apps/<service> for the Pi's CPU and pushes it to the registry.
docker_push(){
  local password="${1:-}"
  local service="${2:-}"
  local tag="${3:-latest}"

  [ -n "$password" ] && [ -n "$service" ] \
    || die "usage: ./k3pi push <password> <service> [tag]"

  local context="$ROOT/apps/$service"
  [ -d "$context" ] || die "no app at apps/$service"

  local image="$REGISTRY/$service:$tag"

  # Docker Desktop must be configured to treat this registry as insecure.
  # Newer Docker clients no longer support the old --tls-verify flag on
  # `docker login` for this use case.
  printf '%s' "$password" | docker login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin

  # The Pi is arm64, so build for arm64 regardless of what this machine is.
  docker build --platform linux/arm64 -t "$image" "$context"
  docker push "$image"

  say "Pushed $image"
}
