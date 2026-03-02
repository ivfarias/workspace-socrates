#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: installer/bootstrapping entrypoint.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-socrates.sh" "$@"

