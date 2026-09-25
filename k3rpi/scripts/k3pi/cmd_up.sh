#!/usr/bin/env bash
# Start the containers.
source "$(dirname "$0")/_shared.sh"

require_docker
say "Starting containers"
compose up -d --build
compose ps
