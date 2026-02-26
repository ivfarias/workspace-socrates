#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  init-spec.sh --repo <repo-path> --name <spec-name> [options]

Options:
  --path <spec-path>     Explicit output path (defaults to <repo>/.clawdbot/specs/<name>.json)
  --overwrite            Overwrite existing file
  --preset <preset>      basic | build-artifact (default: basic)

Examples:
  ./scripts/init-spec.sh --repo /path/to/repo --name docs-sync
  ./scripts/init-spec.sh --repo /path/to/repo --name web-build --preset build-artifact
EOF
}

repo=""
name=""
path_override=""
overwrite="false"
preset="basic"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --path) path_override="$2"; shift 2 ;;
    --overwrite) overwrite="true"; shift ;;
    --preset) preset="$2"; shift 2 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$repo" || -z "$name" ]]; then
  usage
  exit 1
fi

repo="$(cd "$repo" && pwd)"
if [[ ! -d "$repo/.git" ]]; then
  echo "Not a git repository: $repo" >&2
  exit 1
fi

if [[ "$preset" != "basic" && "$preset" != "build-artifact" ]]; then
  echo "Unsupported preset '$preset'. Expected: basic or build-artifact." >&2
  exit 1
fi

slug="$(printf '%s' "$name" | tr -cs '[:alnum:]_-' '-')"
default_dir="$repo/.clawdbot/specs"
default_path="$default_dir/$slug.json"

if [[ -n "$path_override" ]]; then
  if [[ "$path_override" = /* ]]; then
    out_path="$path_override"
  else
    out_path="$repo/$path_override"
  fi
else
  out_path="$default_path"
fi

mkdir -p "$(dirname "$out_path")"
if [[ -f "$out_path" && "$overwrite" != "true" ]]; then
  echo "Spec file already exists: $out_path" >&2
  echo "Use --overwrite to replace it." >&2
  exit 1
fi

case "$preset" in
  basic)
    cat > "$out_path" <<EOF
{
  "name": "$name",
  "checks": [
    {
      "type": "file_exists",
      "path": "artifacts/result.txt"
    },
    {
      "type": "file_contains",
      "path": "artifacts/result.txt",
      "pattern": "PASS"
    }
  ]
}
EOF
    ;;
  build-artifact)
    cat > "$out_path" <<EOF
{
  "name": "$name",
  "checks": [
    {
      "type": "command",
      "cwd": ".",
      "command": "npm run build",
      "expectExit": 0
    },
    {
      "type": "file_exists",
      "path": "dist/index.js"
    }
  ]
}
EOF
    ;;
esac

echo "Created spec: $out_path"
