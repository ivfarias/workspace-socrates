#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: begin inquiry by generating a no-PR spec scaffold.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/init-spec.sh" "$@"

