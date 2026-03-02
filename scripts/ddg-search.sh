#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/ddg-search.sh --query "<text>" [options]

Options:
  -q, --query <text>         Search query (required)
  -m, --max-results <n>      Max results (default: 5)
  -r, --region <region>      Region, e.g. us-en, wt-wt, br-pt
  -s, --safesearch <mode>    on|moderate|off (default: moderate)
  -t, --timelimit <range>    d|w|m|y (day/week/month/year)
  -h, --help                 Show help

Notes:
  - Uses DuckDuckGo via `uvx --from duckduckgo-search ddgs` (no API key required).
  - Requires network access at runtime.
EOF
}

QUERY=""
MAX_RESULTS="5"
REGION=""
SAFESEARCH="moderate"
TIMELIMIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--query)
      QUERY="${2:?missing value for $1}"
      shift 2
      ;;
    -m|--max-results)
      MAX_RESULTS="${2:?missing value for $1}"
      shift 2
      ;;
    -r|--region)
      REGION="${2:?missing value for $1}"
      shift 2
      ;;
    -s|--safesearch)
      SAFESEARCH="${2:?missing value for $1}"
      shift 2
      ;;
    -t|--timelimit)
      TIMELIMIT="${2:?missing value for $1}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$QUERY" ]]; then
  echo "Error: --query is required." >&2
  usage >&2
  exit 2
fi

if ! command -v uvx >/dev/null 2>&1; then
  echo "Error: uvx is required (install uv first)." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required." >&2
  exit 1
fi

tmp_base="$(mktemp /tmp/ddg-search.XXXXXX)"
tmp_json="${tmp_base}.json"
trap 'rm -f "$tmp_json"' EXIT

cmd=(
  uvx --from duckduckgo-search ddgs text
  -k "$QUERY"
  -m "$MAX_RESULTS"
  -s "$SAFESEARCH"
  -b auto
  -o "$tmp_json"
)

if [[ -n "$REGION" ]]; then
  cmd+=(-r "$REGION")
fi

if [[ -n "$TIMELIMIT" ]]; then
  cmd+=(-t "$TIMELIMIT")
fi

# Filter only known rename-warning noise while keeping other stderr output.
"${cmd[@]}" >/dev/null 2> >(
  awk '!/duckduckgo_search\/cli.py|has been renamed to `ddgs`|data = DDGS\(proxy/' >&2
)

if [[ ! -s "$tmp_json" ]]; then
  echo "No results."
  exit 0
fi

jq -r '
  to_entries[]
  | "\(.key + 1). \(.value.title // "(no title)")\n\(.value.href // "")\n\(.value.body // "")\n"
' "$tmp_json"
