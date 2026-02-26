#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ci-pr-check.sh <PR_NUMBER> [REPO_PATH]

Outputs:
  JSON summary with CI/review/screenshot/merge readiness signals.
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required for PR checks." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for PR checks." >&2
  exit 2
fi

pr_number="$1"
repo_path="${2:-}"

if [[ -n "$repo_path" ]]; then
  cd "$repo_path"
fi

pr_json="$(gh pr view "$pr_number" --json body,mergeStateStatus,statusCheckRollup,reviews 2>/dev/null || true)"
if [[ -z "$pr_json" ]]; then
  echo "Unable to fetch PR #$pr_number." >&2
  exit 3
fi

summary="$(jq '
  def check_name($c): ($c.name // $c.context // $c.workflowName // $c.title // "");
  def check_state($c): (($c.conclusion // $c.state // $c.status // "") | ascii_upcase);
  def success_state($s): ($s == "SUCCESS" or $s == "NEUTRAL" or $s == "SKIPPED" or $s == "PASS");
  def failure_state($s): ($s == "FAILURE" or $s == "TIMED_OUT" or $s == "CANCELLED" or $s == "ACTION_REQUIRED" or $s == "STARTUP_FAILURE" or $s == "ERROR");
  def pending_state($s): ($s == "" or $s == "PENDING" or $s == "IN_PROGRESS" or $s == "QUEUED" or $s == "WAITING" or $s == "REQUESTED" or $s == "EXPECTED");
  def reviewer_passed($needle):
    (
      ([.statusCheckRollup[]? | {name: check_name(.), state: check_state(.)}]
        | any((.name | test($needle; "i")) and success_state(.state)))
      or
      ([.reviews[]? | {state: (.state // ""), author: (.author.login // ""), body: (.body // "")}]
        | any((.state == "APPROVED") and ((.author | test($needle; "i")) or (.body | test($needle; "i")))))
    );

  (.statusCheckRollup // []) as $checks
  | ($checks | map(check_state(.))) as $states
  | ($states | length) as $total
  | ($states | any(failure_state(.))) as $has_failure
  | ($states | any(pending_state(.))) as $has_pending
  | ($checks | map(check_name(.))) as $check_names
  | {
      ciState:
        (if $total == 0 then "none"
         elif $has_failure then "failed"
         elif $has_pending then "pending"
         else "passed"
         end),
      ciPassed: ($total > 0 and (not $has_failure) and (not $has_pending)),
      mergeStateStatus: (.mergeStateStatus // "UNKNOWN"),
      branchUpToDate: ((.mergeStateStatus // "UNKNOWN") | IN("CLEAN", "HAS_HOOKS")),
      screenshotIncluded: ((.body // "") | test("!\\[[^\\]]*\\]\\([^\\)]*\\)|https?://[^\\s\\)]+\\.(png|jpe?g|gif|webp)"; "i")),
      codexReviewPassed: reviewer_passed("codex|gpt-5|openai"),
      claudeReviewPassed: reviewer_passed("claude|anthropic"),
      geminiReviewPassed: reviewer_passed("gemini|google"),
      criticalReviewFeedback:
        (
          [.reviews[]?]
          | any(
              (.state == "CHANGES_REQUESTED")
              or ((.body // "") | test("\\bcritical\\b|\\bblocker\\b|\\bmust[- ]?fix\\b"; "i"))
            )
        ),
      checkNames: $check_names
    }
' <<<"$pr_json")"

jq -n --argjson summary "$summary" --argjson pr "$pr_number" '
  $summary + { pr: $pr }
'
