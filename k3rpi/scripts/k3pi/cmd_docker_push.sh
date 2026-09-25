#!/usr/bin/env bash
# Build an app and push it to the registry on the Pi.
# usage: ./k3pi push <password> <service> [tag]
source "$(dirname "$0")/_shared.sh"

require_docker
say "Pushing docker image"
docker_push "$@"
