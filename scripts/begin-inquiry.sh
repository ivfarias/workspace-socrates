#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: alternate name for inquiry/spec initialization.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/init-spec.sh" "$@"

