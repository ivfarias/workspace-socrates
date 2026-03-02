#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: PR reviewer gate validation.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify-reviewers.sh" "$@"

