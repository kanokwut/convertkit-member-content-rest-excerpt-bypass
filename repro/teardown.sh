#!/usr/bin/env bash
cd "$(dirname "$0")"
docker compose -p ck349 down -v --remove-orphans
