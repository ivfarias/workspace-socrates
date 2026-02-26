#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  verify-reviewers.sh [--repo <repo-path>] [--pr <number>]

Checks whether Codex/Claude/Gemini reviewer signals are visible on a PR.
Requires:
  - gh authenticated to github.com
  - access to the target repository
EOF
}

repo_path=""
pr_number=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo_path="$2"; shift 2 ;;
    --pr) pr_number="$2"; shift 2 ;;
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

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 2
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated. Run: gh auth login -h github.com" >&2
  exit 3
fi

if [[ -n "$repo_path" ]]; then
  cd "$repo_path"
fi

if [[ -z "$pr_number" ]]; then
  pr_number="$(gh pr list --state open --limit 1 --json number -q '.[0].number' 2>/dev/null || true)"
fi
if [[ -z "$pr_number" ]]; then
  echo "No open PR found to inspect." >&2
  exit 4
fi

pr_json="$(gh pr view "$pr_number" --json number,statusCheckRollup,reviews 2>/dev/null || true)"
if [[ -z "$pr_json" ]]; then
  echo "Unable to load PR #$pr_number." >&2
  exit 5
fi

jq '
  def check_name($c): ($c.name // $c.context // $c.workflowName // $c.title // "");
  def check_state($c): (($c.conclusion // $c.state // $c.status // "") | ascii_upcase);
  def success_state($s): ($s == "SUCCESS" or $s == "NEUTRAL" or $s == "SKIPPED" or $s == "PASS");
  def reviewer_ok($needle):
    (
      ([.statusCheckRollup[]? | {name: check_name(.), state: check_state(.)}]
        | any((.name | test($needle; "i")) and success_state(.state)))
      or
      ([.reviews[]? | {state: (.state // ""), author: (.author.login // ""), body: (.body // "")}]
        | any((.state == "APPROVED") and ((.author | test($needle; "i")) or (.body | test($needle; "i")))))
    );
  {
    pr: .number,
    codexReviewPassed: reviewer_ok("codex|gpt-5|openai"),
    claudeReviewPassed: reviewer_ok("claude|anthropic"),
    geminiReviewPassed: reviewer_ok("gemini|google")
  }
' <<<"$pr_json"
