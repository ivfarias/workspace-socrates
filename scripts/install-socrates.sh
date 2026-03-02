#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-socrates.sh [options]

Options:
  --workspace <dir>       Workspace path to register (default: script parent dir)
  --agent-id <id>         Agent id (default: socrates)
  --set-default           Mark this agent as default (sets .default=true on this agent)
  --model-primary <id>    Explicit primary model override for this agent only
  --fallback <id>         Explicit fallback model for this agent (repeatable)
  --wizard-model          Interactive model prompt (optional; not default)
  --set-global-model-defaults
                          Also write explicit model values to agents.defaults.model.*
  --config-path <path>    OpenClaw config path (default: $OPENCLAW_CONFIG_PATH or ~/.openclaw/openclaw.json)
  -h, --help              Show this help

What this script does:
  1) Ensures an agent entry exists (or updates existing) for Socrates workspace
  2) Inherits existing model setup by default (no forced override)
  3) Applies explicit model overrides only when flags are passed
  4) Applies identity from IDENTITY.md (including avatar)
  5) Prints next steps for auth/channels
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKSPACE_DIR="$DEFAULT_WORKSPACE"
AGENT_ID="socrates"
SET_DEFAULT="false"
MODEL_PRIMARY=""
WIZARD_MODEL="false"
SET_GLOBAL_MODEL_DEFAULTS="false"
FALLBACKS=()
CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    --agent-id)
      AGENT_ID="$2"
      shift 2
      ;;
    --set-default)
      SET_DEFAULT="true"
      shift
      ;;
    --model-primary)
      MODEL_PRIMARY="$2"
      shift 2
      ;;
    --fallback)
      FALLBACKS+=("$2")
      shift 2
      ;;
    --wizard-model)
      WIZARD_MODEL="true"
      shift
      ;;
    --set-global-model-defaults)
      SET_GLOBAL_MODEL_DEFAULTS="true"
      shift
      ;;
    --config-path)
      CONFIG_PATH="$2"
      shift 2
      ;;
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

require_cmd jq
require_cmd openclaw

WORKSPACE_DIR="$(cd "$WORKSPACE_DIR" && pwd)"

if [[ ! -d "$WORKSPACE_DIR" ]]; then
  echo "Workspace does not exist: $WORKSPACE_DIR" >&2
  exit 1
fi

if [[ ! -f "$WORKSPACE_DIR/IDENTITY.md" ]]; then
  echo "Missing IDENTITY.md in workspace: $WORKSPACE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$CONFIG_PATH")"
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "{}" > "$CONFIG_PATH"
fi

backup_path="${CONFIG_PATH}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_PATH" "$backup_path"

if [[ "$WIZARD_MODEL" == "true" ]]; then
  current_default_primary="$(jq -r '.agents.defaults.model.primary // empty' "$CONFIG_PATH")"
  current_agent_primary="$(jq -r --arg id "$AGENT_ID" '.agents.list[]? | select(.id==$id) | (.model.primary // .model // empty)' "$CONFIG_PATH" | head -n 1)"
  echo "Model wizard (optional overrides). Leave blank to inherit existing config."
  echo "Current agent primary: ${current_agent_primary:-<none>}"
  echo "Current defaults primary: ${current_default_primary:-<none>}"
  read -r -p "Primary model override for $AGENT_ID: " wizard_primary || true
  if [[ -n "${wizard_primary:-}" ]]; then
    MODEL_PRIMARY="$wizard_primary"
  fi
  read -r -p "Fallbacks override (comma-separated, blank to keep/inherit): " wizard_fallbacks || true
  if [[ -n "${wizard_fallbacks:-}" ]]; then
    FALLBACKS=()
    IFS=',' read -r -a _parsed <<< "$wizard_fallbacks"
    for item in "${_parsed[@]}"; do
      trimmed="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ -n "$trimmed" ]]; then
        FALLBACKS+=("$trimmed")
      fi
    done
  fi
fi

EXPLICIT_FALLBACKS_JSON="null"
if [[ "${#FALLBACKS[@]}" -gt 0 ]]; then
  EXPLICIT_FALLBACKS_JSON="$(jq -n --args '$ARGS.positional' "${FALLBACKS[@]}")"
fi

tmp_json="$(mktemp)"
jq \
  --arg agent_id "$AGENT_ID" \
  --arg workspace "$WORKSPACE_DIR" \
  --argjson set_default "$SET_DEFAULT" \
  --arg model_primary "$MODEL_PRIMARY" \
  --argjson explicit_fallbacks "$EXPLICIT_FALLBACKS_JSON" \
  --argjson set_global_model_defaults "$SET_GLOBAL_MODEL_DEFAULTS" \
  '
  def defaults_primary:
    .agents.defaults.model.primary // "";

  def defaults_fallbacks:
    if (.agents.defaults.model.fallbacks | type) == "array" then .agents.defaults.model.fallbacks else [] end;

  def base_model($current; $default_primary; $default_fallbacks):
    if ($current | type) == "object" then
      {
        primary: ($current.primary // $default_primary),
        fallbacks: (
          if ($current.fallbacks | type) == "array"
          then $current.fallbacks
          else $default_fallbacks
          end
        )
      }
    elif ($current | type) == "string" then
      {
        primary: $current,
        fallbacks: $default_fallbacks
      }
    elif $default_primary != "" then
      {
        primary: $default_primary,
        fallbacks: $default_fallbacks
      }
    else
      {}
    end;

  def apply_model_overrides($model; $explicit_primary; $explicit_fallbacks):
    (
      $model
      | if $explicit_primary != "" then .primary = $explicit_primary else . end
      | if ($explicit_fallbacks | type) == "array" then .fallbacks = $explicit_fallbacks else . end
    )
    | if (.primary // "") == "" then del(.primary) else . end
    | if (.fallbacks | type) != "array" then del(.fallbacks) else . end
    | if (.fallbacks | type) == "array" and (.fallbacks | length) == 0 then del(.fallbacks) else . end;

  .agents = (.agents // {}) |
  .agents.defaults = (.agents.defaults // {}) |
  .agents.defaults.model = (.agents.defaults.model // {}) |
  defaults_primary as $default_primary |
  defaults_fallbacks as $default_fallbacks |
  .agents.list = (.agents.list // []) |
  if any(.agents.list[]?; .id == $agent_id) then
    .agents.list |= map(
      if .id == $agent_id then
        (
          apply_model_overrides(
            base_model(.model; $default_primary; $default_fallbacks);
            $model_primary;
            $explicit_fallbacks
          )
        ) as $updated_model
        | .workspace = $workspace
        | .name = (.name // $agent_id)
        | if ($updated_model | length) > 0 then .model = $updated_model else del(.model) end
      else
        .
      end
    )
  else
    (
      apply_model_overrides(
        base_model(null; $default_primary; $default_fallbacks);
        $model_primary;
        $explicit_fallbacks
      )
    ) as $new_model
    | .agents.list += [(
      {
        "id": $agent_id,
        "name": $agent_id,
        "workspace": $workspace
      } + (if ($new_model | length) > 0 then {"model": $new_model} else {} end)
    )]
  end |
  if $set_global_model_defaults then
    (
      if $model_primary != "" then
        .agents.defaults.model.primary = $model_primary
      else
        .
      end
    )
    |
    (
      if ($explicit_fallbacks | type) == "array" then
        .agents.defaults.model.fallbacks = $explicit_fallbacks
      else
        .
      end
    )
  else
    .
  end |
  .tools = (.tools // {}) |
  .tools.web = (.tools.web // {}) |
  .tools.web.search = (.tools.web.search // {}) |
  .tools.web.search.enabled = false |
  .tools.web.fetch = (.tools.web.fetch // {}) |
  .tools.web.fetch.enabled = true |
  if $set_default then
    .agents.list |= map(.default = (.id == $agent_id))
  else
    .
  end
  ' "$CONFIG_PATH" > "$tmp_json"

mv "$tmp_json" "$CONFIG_PATH"

OPENCLAW_CONFIG_PATH="$CONFIG_PATH" openclaw agents set-identity \
  --agent "$AGENT_ID" \
  --workspace "$WORKSPACE_DIR" \
  --from-identity >/dev/null

echo "Socrates workspace installed."
echo "Agent id: $AGENT_ID"
echo "Workspace: $WORKSPACE_DIR"
echo "Config: $CONFIG_PATH"
echo "Backup: $backup_path"
echo
echo "Validate:"
echo "  OPENCLAW_CONFIG_PATH=\"$CONFIG_PATH\" openclaw agents list --json | jq '.[] | select(.id==\"$AGENT_ID\")'"
echo
echo "Next steps:"
echo "  1) openclaw configure                # connect auth providers/channels on this machine"
echo "  2) openclaw agent --agent $AGENT_ID --message \"Hello Socrates\""
echo "  3) (optional) openclaw sessions --agent $AGENT_ID"
echo "  4) Web search: ./scripts/ddg-search.sh --query \"<topic>\" --max-results 5"
