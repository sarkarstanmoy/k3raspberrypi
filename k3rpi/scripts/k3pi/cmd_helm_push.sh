#!/usr/bin/env bash
# Package an app's Helm chart and push it to the registry on the Pi.
# usage: ./k3pi helm push <service> [version]
source "$(dirname "$0")/_shared.sh"

command -v helm >/dev/null || die "helm is not installed"

service="${1:-}"
[ -n "$service" ] || die "usage: ./k3pi helm push <service> [version]"

chart="$ROOT/apps/$service/chart"
[ -f "$chart/Chart.yaml" ] || die "no chart at apps/$service/chart"

# Default version: <major>.<minor> from Chart.yaml plus a UTC timestamp as the
# patch, e.g. 0.1.20260926143015. Helm needs SemVer, and a timestamp in the
# patch slot has no leading zeros and sorts newest-last.
version="${2:-}"
if [ -z "$version" ]; then
  base="$(awk '/^version:/ { gsub(/["'\'']/, "", $2); print $2 }' "$chart/Chart.yaml")"
  major_minor="$(printf '%s' "$base" | cut -d. -f1-2)"
  version="$major_minor.$(date -u +%Y%m%d%H%M%S)"
fi

# The password comes from $ZOT_PASSWORD, or is asked for.
password="${ZOT_PASSWORD:-}"
if [ -z "$password" ]; then
  read -rsp "Password for $REGISTRY_USER@$REGISTRY: " password
  echo
fi

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

say "Linting chart"
helm lint "$chart"

say "Packaging $service $version"
helm package "$chart" --version "$version" -d "$out"

# The registry is plain HTTP, same as for docker push.
printf '%s' "$password" | helm registry login "$REGISTRY" --plain-http \
  -u "$REGISTRY_USER" --password-stdin

helm push "$out/$service-$version.tgz" "oci://$REGISTRY/charts" --plain-http

say "Pushed oci://$REGISTRY/charts/$service:$version"
echo "Install with:"
echo "  helm upgrade --install $service oci://$REGISTRY/charts/$service --version $version --plain-http"
