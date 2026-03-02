#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: PR reviewer-signal gate check.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verify-reviewers.sh" "$@"

