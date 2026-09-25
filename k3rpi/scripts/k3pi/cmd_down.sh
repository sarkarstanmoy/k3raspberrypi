#!/usr/bin/env bash
# Stop the containers.
source "$(dirname "$0")/_shared.sh"

require_docker
say "Stopping containers"
compose down
