# Shared settings and helpers. Sourced by the other scripts in this folder,
# not run on its own.

set -euo pipefail

# repo root, two levels up from scripts/k3pi/
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$ROOT/docker-compose.yml"

say() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
die() { printf '\n\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }

require_docker() {
  command -v docker >/dev/null || die "docker is not installed"
  docker info >/dev/null 2>&1 || die "Docker isn't running - start Docker Desktop"
}
