#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_PATH="$WORKSPACE_ROOT/.clawdbot/active-tasks.json"
CONFIG_PATH="$WORKSPACE_ROOT/.clawdbot/config.json"
CI_CHECK_SCRIPT="$SCRIPT_DIR/ci-pr-check.sh"

usage() {
  cat <<'EOF'
Usage:
  check-agents.sh [--task-id <id>] [--no-respawn]

Behavior:
  - Reads .clawdbot/active-tasks.json
  - Updates tmux/session/PR/CI/review state per task
  - Supports completionMode:
      - pr (default): requires PR/CI/review checks
      - no-pr-spec: requires spec evidence checks
  - Auto-respawns tasks on configured failures (max attempts)
  - Writes updated registry back in place
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

set_check_bool() {
  local task_json="$1"
  local check_name="$2"
  local check_value="$3"
  jq --arg check "$check_name" --argjson value "$check_value" '.checks[$check] = $value' <<<"$task_json"
}

resolve_path() {
  local base_dir="$1"
  local input_path="$2"

  if [[ -z "$input_path" ]]; then
    echo ""
    return
  fi
  if [[ "$input_path" = /* ]]; then
    echo "$input_path"
    return
  fi
  if [[ -z "$base_dir" ]]; then
    echo "$input_path"
    return
  fi
  echo "$base_dir/$input_path"
}

spawn_session_from_task() {
  local task_json="$1"
  local session launch_script worktree log_file

  if [[ "$tmux_available" != "true" ]]; then
    return 1
  fi

  session="$(jq -r '.tmuxSession // ""' <<<"$task_json")"
  launch_script="$(jq -r '.runtime.launchScript // ""' <<<"$task_json")"
  worktree="$(jq -r '.worktree // ""' <<<"$task_json")"
  log_file="$(jq -r '.runtime.logFile // ""' <<<"$task_json")"

  if [[ -z "$session" || -z "$launch_script" || -z "$worktree" ]]; then
    return 1
  fi
  if [[ ! -x "$launch_script" || ! -d "$worktree" ]]; then
    return 1
  fi
  if tmux has-session -t "$session" 2>/dev/null; then
    return 0
  fi

  tmux new-session -d -s "$session" -c "$worktree" "$launch_script"
  if [[ -n "$log_file" ]]; then
    tmux pipe-pane -o -t "$session" "cat >> '$log_file'"
  fi
}

evaluate_no_pr_spec() {
  local task_json="$1"
  local spec_file worktree checked_at checks_len
  local failures_file evidence_file

  checked_at="$(now_ms)"
  spec_file="$(jq -r '.specFile // ""' <<<"$task_json")"
  worktree="$(jq -r '.worktree // ""' <<<"$task_json")"
  spec_file="$(resolve_path "$worktree" "$spec_file")"

  failures_file="$(mktemp)"
  evidence_file="$(mktemp)"

  if [[ -z "$spec_file" ]]; then
    jq -n --arg reason "spec_file_missing" '{reason: $reason}' > "$failures_file"
  elif [[ ! -f "$spec_file" ]]; then
    jq -n --arg reason "spec_file_not_found" --arg path "$spec_file" '{reason: $reason, path: $path}' > "$failures_file"
  elif ! jq . "$spec_file" >/dev/null 2>&1; then
    jq -n --arg reason "spec_file_invalid_json" --arg path "$spec_file" '{reason: $reason, path: $path}' > "$failures_file"
  else
    checks_len="$(jq -r '.checks | if type=="array" then length else -1 end' "$spec_file")"
    if (( checks_len < 0 )); then
      jq -n --arg reason "spec_checks_missing" --arg path "$spec_file" '{reason: $reason, path: $path}' > "$failures_file"
    elif (( checks_len == 0 )); then
      jq -n --arg reason "spec_checks_empty" --arg path "$spec_file" '{reason: $reason, path: $path}' > "$failures_file"
    else
      while IFS= read -r check; do
        local type path pattern cmd check_cwd expect_exit target_path resolved_cwd cmd_output runner_cmd rc
        type="$(jq -r '.type // ""' <<<"$check")"
        case "$type" in
          file_exists)
            path="$(jq -r '.path // ""' <<<"$check")"
            target_path="$(resolve_path "$worktree" "$path")"
            if [[ -n "$target_path" && -f "$target_path" ]]; then
              jq -n --arg type "$type" --arg path "$target_path" '{type: $type, ok: true, path: $path}' >> "$evidence_file"
            else
              jq -n --arg reason "file_missing" --arg type "$type" --arg path "$target_path" '{reason: $reason, type: $type, path: $path}' >> "$failures_file"
            fi
            ;;
          file_contains)
            path="$(jq -r '.path // ""' <<<"$check")"
            pattern="$(jq -r '.pattern // ""' <<<"$check")"
            target_path="$(resolve_path "$worktree" "$path")"
            if [[ -z "$target_path" || ! -f "$target_path" ]]; then
              jq -n --arg reason "file_missing" --arg type "$type" --arg path "$target_path" '{reason: $reason, type: $type, path: $path}' >> "$failures_file"
            elif [[ -z "$pattern" ]]; then
              jq -n --arg reason "pattern_missing" --arg type "$type" --arg path "$target_path" '{reason: $reason, type: $type, path: $path}' >> "$failures_file"
            elif rg -q -- "$pattern" "$target_path"; then
              jq -n --arg type "$type" --arg path "$target_path" --arg pattern "$pattern" '{type: $type, ok: true, path: $path, pattern: $pattern}' >> "$evidence_file"
            else
              jq -n --arg reason "pattern_not_found" --arg type "$type" --arg path "$target_path" --arg pattern "$pattern" '{reason: $reason, type: $type, path: $path, pattern: $pattern}' >> "$failures_file"
            fi
            ;;
          command)
            cmd="$(jq -r '.command // ""' <<<"$check")"
            check_cwd="$(jq -r '.cwd // "."' <<<"$check")"
            expect_exit="$(jq -r '.expectExit // 0' <<<"$check")"
            resolved_cwd="$(resolve_path "$worktree" "$check_cwd")"
            if [[ -z "$cmd" ]]; then
              jq -n --arg reason "command_missing" --arg type "$type" '{reason: $reason, type: $type}' >> "$failures_file"
            elif [[ -z "$resolved_cwd" || ! -d "$resolved_cwd" ]]; then
              jq -n --arg reason "command_cwd_missing" --arg type "$type" --arg cwd "$resolved_cwd" '{reason: $reason, type: $type, cwd: $cwd}' >> "$failures_file"
            else
              printf -v runner_cmd 'cd %q && %s' "$resolved_cwd" "$cmd"
              if cmd_output="$(bash -lc "$runner_cmd" 2>&1)"; then
                rc=0
              else
                rc=$?
              fi

              if [[ "$rc" == "$expect_exit" ]]; then
                jq -n --arg type "$type" --arg cmd "$cmd" --arg cwd "$resolved_cwd" --argjson exitCode "$rc" '{type: $type, ok: true, command: $cmd, cwd: $cwd, exitCode: $exitCode}' >> "$evidence_file"
              else
                jq -n \
                  --arg reason "command_exit_mismatch" \
                  --arg type "$type" \
                  --arg cmd "$cmd" \
                  --arg cwd "$resolved_cwd" \
                  --arg output "$(printf '%s' "$cmd_output" | tail -n 20)" \
                  --argjson expected "$expect_exit" \
                  --argjson actual "$rc" \
                  '{reason: $reason, type: $type, command: $cmd, cwd: $cwd, expectedExit: $expected, actualExit: $actual, output: $output}' \
                  >> "$failures_file"
              fi
            fi
            ;;
          *)
            jq -n --arg reason "unsupported_check_type" --arg type "$type" '{reason: $reason, type: $type}' >> "$failures_file"
            ;;
        esac
      done < <(jq -c '.checks[]' "$spec_file")
    fi
  fi

  local failures_json evidence_json success_json
  if [[ -s "$failures_file" ]]; then
    failures_json="$(jq -s '.' "$failures_file")"
  else
    failures_json='[]'
  fi
  if [[ -s "$evidence_file" ]]; then
    evidence_json="$(jq -s '.' "$evidence_file")"
  else
    evidence_json='[]'
  fi

  if [[ "$(jq -r 'length' <<<"$failures_json")" == "0" ]]; then
    success_json="true"
  else
    success_json="false"
  fi

  jq -n \
    --arg specFile "$spec_file" \
    --argjson checkedAt "$checked_at" \
    --argjson success "$success_json" \
    --argjson failures "$failures_json" \
    --argjson evidence "$evidence_json" \
    '{
      checkedAt: $checkedAt,
      specFile: $specFile,
      success: $success,
      failures: $failures,
      evidence: $evidence
    }'

  rm -f "$failures_file" "$evidence_file"
}

task_filter=""
no_respawn="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) task_filter="$2"; shift 2 ;;
    --no-respawn) no_respawn="true"; shift ;;
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
mkdir -p "$(dirname "$REGISTRY_PATH")"
if [[ ! -f "$REGISTRY_PATH" ]]; then
  echo "[]" > "$REGISTRY_PATH"
fi

max_attempts=3
auto_respawn_session_exit="true"
auto_respawn_ci_failure="true"
auto_respawn_critical_review="true"

if [[ -f "$CONFIG_PATH" ]]; then
  max_attempts="$(jq -r '.retryPolicy.maxAttempts // 3' "$CONFIG_PATH")"
  auto_respawn_session_exit="$(jq -r '.retryPolicy.autoRespawnOnSessionExit // true' "$CONFIG_PATH")"
  auto_respawn_ci_failure="$(jq -r '.retryPolicy.autoRespawnOnCiFailure // true' "$CONFIG_PATH")"
  auto_respawn_critical_review="$(jq -r '.retryPolicy.autoRespawnOnCriticalReview // true' "$CONFIG_PATH")"
fi
if [[ "$no_respawn" == "true" ]]; then
  auto_respawn_session_exit="false"
  auto_respawn_ci_failure="false"
  auto_respawn_critical_review="false"
fi

required_checks='["prCreated","ciPassed","branchUpToDate","codexReviewPassed","claudeReviewPassed","geminiReviewPassed"]'
if [[ -f "$CONFIG_PATH" ]]; then
  required_checks="$(jq -c '.doneCriteria.requiredChecks // ["prCreated","ciPassed","branchUpToDate"]' "$CONFIG_PATH")"
fi

tmp_ndjson="$(mktemp)"
summary_checked=0
summary_done=0
summary_retried=0
summary_attention=0
current_ts="$(now_ms)"
gh_available="false"
if command -v gh >/dev/null 2>&1; then
  gh_available="true"
fi
tmux_available="false"
if command -v tmux >/dev/null 2>&1; then
  tmux_available="true"
fi
if [[ "$tmux_available" != "true" ]]; then
  echo "Warning: tmux not found. Session checks and auto-respawn are disabled."
fi

while IFS= read -r task; do
  if [[ -n "$task_filter" ]]; then
    task_id="$(jq -r '.id // ""' <<<"$task")"
    if [[ "$task_id" != "$task_filter" ]]; then
      echo "$task" >> "$tmp_ndjson"
      continue
    fi
  fi

  summary_checked=$((summary_checked + 1))

  task="$(jq --argjson ts "$current_ts" '
    .updatedAt = $ts
    | .checks = (.checks // {})
    | .checks.prCreated = (.checks.prCreated // false)
    | .checks.ciPassed = (.checks.ciPassed // false)
    | .checks.branchUpToDate = (.checks.branchUpToDate // false)
    | .checks.codexReviewPassed = (.checks.codexReviewPassed // false)
    | .checks.claudeReviewPassed = (.checks.claudeReviewPassed // false)
    | .checks.geminiReviewPassed = (.checks.geminiReviewPassed // false)
    | .checks.screenshotIncluded = (.checks.screenshotIncluded // false)
    | .attempt = (.attempt // 1)
    | .maxRetries = (.maxRetries // 3)
    | .completionMode = (.completionMode // "pr")
    | .specFile = (.specFile // "")
  ' <<<"$task")"

  status="$(jq -r '.status // "running"' <<<"$task")"
  completion_mode="$(jq -r '.completionMode // "pr"' <<<"$task")"
  session="$(jq -r '.tmuxSession // ""' <<<"$task")"
  branch="$(jq -r '.branch // ""' <<<"$task")"
  repo_path="$(jq -r '.repoPath // .worktree // ""' <<<"$task")"
  pr_number="$(jq -r '.pr // empty' <<<"$task")"
  attempt="$(jq -r '.attempt // 1' <<<"$task")"
  max_retries="$(jq -r --argjson m "$max_attempts" '.maxRetries // $m' <<<"$task")"

  session_alive="false"
  if [[ "$tmux_available" == "true" && -n "$session" ]] && tmux has-session -t "$session" 2>/dev/null; then
    session_alive="true"
  fi
  task="$(jq --argjson alive "$session_alive" '.sessionAlive = $alive' <<<"$task")"

  if [[ "$status" == "done" || "$status" == "cancelled" ]]; then
    echo "$task" >> "$tmp_ndjson"
    continue
  fi

  if [[ "$completion_mode" == "no-pr-spec" ]]; then
    if [[ "$session_alive" == "true" ]]; then
      status="$(jq -r '.status // "running"' <<<"$task")"
      if [[ "$status" != "retrying" ]]; then
        task="$(jq '.status = "running"' <<<"$task")"
      fi
    else
      spec_eval="$(evaluate_no_pr_spec "$task")"
      task="$(jq --argjson eval "$spec_eval" '.specEvaluation = $eval' <<<"$task")"
      spec_ok="$(jq -r '.success // false' <<<"$spec_eval")"

      if [[ "$spec_ok" == "true" ]]; then
        task="$(jq --argjson ts "$current_ts" '.status = "done" | .completedAt = $ts' <<<"$task")"
        summary_done=$((summary_done + 1))
      else
        if [[ "$auto_respawn_session_exit" == "true" && $attempt -lt $max_retries ]]; then
          if spawn_session_from_task "$task"; then
            task="$(jq '.status = "retrying"' <<<"$task")"
            task="$(jq --argjson n $((attempt + 1)) '.attempt = $n' <<<"$task")"
            task="$(jq --argjson ts "$current_ts" --argjson failures "$(jq -c '.failures // []' <<<"$spec_eval")" '.lastFailure = {reason: "no_pr_spec_unmet", at: $ts, failures: $failures}' <<<"$task")"
            task="$(jq '.sessionAlive = true' <<<"$task")"
            summary_retried=$((summary_retried + 1))
          else
            task="$(jq --argjson ts "$current_ts" --argjson failures "$(jq -c '.failures // []' <<<"$spec_eval")" '.status = "needs_attention" | .lastFailure = {reason: "no_pr_spec_unmet", at: $ts, failures: $failures}' <<<"$task")"
          fi
        else
          task="$(jq --argjson ts "$current_ts" --argjson failures "$(jq -c '.failures // []' <<<"$spec_eval")" '.status = "needs_attention" | .lastFailure = {reason: "no_pr_spec_unmet", at: $ts, failures: $failures}' <<<"$task")"
        fi
      fi
    fi

    final_status="$(jq -r '.status // "running"' <<<"$task")"
    if [[ "$final_status" == "needs_attention" ]]; then
      summary_attention=$((summary_attention + 1))
    fi
    echo "$task" >> "$tmp_ndjson"
    continue
  fi

  if [[ "$gh_available" == "true" && -n "$branch" ]]; then
    if [[ -d "$repo_path/.git" ]]; then
      maybe_pr="$(cd "$repo_path" && gh pr list --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null || true)"
    else
      maybe_pr="$(gh pr list --head "$branch" --state open --json number -q '.[0].number' 2>/dev/null || true)"
    fi

    if [[ -n "$maybe_pr" ]]; then
      pr_number="$maybe_pr"
      task="$(jq --argjson pr "$pr_number" '.pr = $pr' <<<"$task")"
      task="$(set_check_bool "$task" "prCreated" "true")"

      if [[ -x "$CI_CHECK_SCRIPT" ]]; then
        if [[ -d "$repo_path/.git" ]]; then
          pr_summary="$("$CI_CHECK_SCRIPT" "$pr_number" "$repo_path" 2>/dev/null || true)"
        else
          pr_summary="$("$CI_CHECK_SCRIPT" "$pr_number" 2>/dev/null || true)"
        fi

        if [[ -n "$pr_summary" ]]; then
          ci_passed="$(jq -r '.ciPassed // false' <<<"$pr_summary")"
          branch_ok="$(jq -r '.branchUpToDate // false' <<<"$pr_summary")"
          screenshot_ok="$(jq -r '.screenshotIncluded // false' <<<"$pr_summary")"
          codex_ok="$(jq -r '.codexReviewPassed // false' <<<"$pr_summary")"
          claude_ok="$(jq -r '.claudeReviewPassed // false' <<<"$pr_summary")"
          gemini_ok="$(jq -r '.geminiReviewPassed // false' <<<"$pr_summary")"
          ci_state="$(jq -r '.ciState // "none"' <<<"$pr_summary")"
          critical_feedback="$(jq -r '.criticalReviewFeedback // false' <<<"$pr_summary")"

          task="$(set_check_bool "$task" "ciPassed" "$ci_passed")"
          task="$(set_check_bool "$task" "branchUpToDate" "$branch_ok")"
          task="$(set_check_bool "$task" "screenshotIncluded" "$screenshot_ok")"
          task="$(set_check_bool "$task" "codexReviewPassed" "$codex_ok")"
          task="$(set_check_bool "$task" "claudeReviewPassed" "$claude_ok")"
          task="$(set_check_bool "$task" "geminiReviewPassed" "$gemini_ok")"
          task="$(jq --arg ciState "$ci_state" '.ciState = $ciState' <<<"$task")"

          if [[ "$critical_feedback" == "true" && "$auto_respawn_critical_review" == "true" ]]; then
            if (( attempt < max_retries )); then
              if [[ "$session_alive" == "true" ]]; then
                tmux send-keys -t "$session" "Critical review feedback detected on PR #$pr_number. Address reviewer blockers, run tests, commit, and push updates." C-m
                task="$(jq '.status = "retrying"' <<<"$task")"
                task="$(jq --argjson n $((attempt + 1)) '.attempt = $n' <<<"$task")"
                task="$(jq --arg reason "critical_review_feedback" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
                task="$(jq '.sessionAlive = true' <<<"$task")"
                summary_retried=$((summary_retried + 1))
                session_alive="true"
              elif spawn_session_from_task "$task"; then
                task="$(jq '.status = "retrying"' <<<"$task")"
                task="$(jq --argjson n $((attempt + 1)) '.attempt = $n' <<<"$task")"
                task="$(jq --arg reason "critical_review_feedback" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
                task="$(jq '.sessionAlive = true' <<<"$task")"
                summary_retried=$((summary_retried + 1))
                session_alive="true"
              fi
            fi
          fi

          if [[ "$ci_state" == "failed" && "$auto_respawn_ci_failure" == "true" ]]; then
            attempt="$(jq -r '.attempt' <<<"$task")"
            if (( attempt < max_retries )); then
              if [[ "$session_alive" == "true" ]]; then
                tmux send-keys -t "$session" "CI failed for PR #$pr_number. Inspect failed checks, fix failures, run tests, then commit and push." C-m
                task="$(jq '.status = "retrying"' <<<"$task")"
                task="$(jq --argjson n $((attempt + 1)) '.attempt = $n' <<<"$task")"
                task="$(jq --arg reason "ci_failed" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
                task="$(jq '.sessionAlive = true' <<<"$task")"
                summary_retried=$((summary_retried + 1))
              elif spawn_session_from_task "$task"; then
                task="$(jq '.status = "retrying"' <<<"$task")"
                task="$(jq --argjson n $((attempt + 1)) '.attempt = $n' <<<"$task")"
                task="$(jq --arg reason "ci_failed" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
                task="$(jq '.sessionAlive = true' <<<"$task")"
                summary_retried=$((summary_retried + 1))
                session_alive="true"
              fi
            fi
          fi
        fi
      fi
    else
      task="$(set_check_bool "$task" "prCreated" "false")"
    fi
  fi

  if [[ "$session_alive" == "false" && "$status" != "done" ]]; then
    attempt="$(jq -r '.attempt // 1' <<<"$task")"
    if [[ "$auto_respawn_session_exit" == "true" && $attempt -lt $max_retries ]]; then
      if spawn_session_from_task "$task"; then
        task="$(jq '.status = "retrying"' <<<"$task")"
        task="$(jq --argjson n $((attempt + 1)) '.attempt = $n' <<<"$task")"
        task="$(jq --arg reason "agent_session_dead" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
        task="$(jq '.sessionAlive = true' <<<"$task")"
        summary_retried=$((summary_retried + 1))
        session_alive="true"
      else
        task="$(jq '.status = "needs_attention"' <<<"$task")"
        task="$(jq --arg reason "agent_session_dead" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
      fi
    else
      task="$(jq '.status = "needs_attention"' <<<"$task")"
      task="$(jq --arg reason "agent_session_dead" --argjson ts "$current_ts" '.lastFailure = {reason: $reason, at: $ts}' <<<"$task")"
    fi
  fi

  requires_screenshot="$(jq -r '.requiresScreenshot // false' <<<"$task")"
  done_expr='
    . as $task
    | all($requiredChecks[]; ($task.checks[.] == true))
      and (($requiresScreenshot | not) or ($task.checks.screenshotIncluded == true))
  '

  is_done="$(jq -r \
    --argjson requiredChecks "$required_checks" \
    --argjson requiresScreenshot "$requires_screenshot" \
    "$done_expr" <<<"$task")"

  if [[ "$is_done" == "true" ]]; then
    prev_status="$(jq -r '.status // "running"' <<<"$task")"
    task="$(jq --argjson ts "$current_ts" '.status = "done" | .completedAt = $ts' <<<"$task")"
    # Phase 9: Mark as simplify_pending if transitioning to done (not already done)
    if [[ "$prev_status" != "done" ]]; then
      task="$(jq '.phase9_status = (.phase9_status // "simplify_pending")' <<<"$task")"
    fi
    summary_done=$((summary_done + 1))
  else
    status="$(jq -r '.status // "running"' <<<"$task")"
    if [[ "$status" != "retrying" && "$status" != "needs_attention" ]]; then
      task="$(jq '.status = "running"' <<<"$task")"
    fi
  fi

  final_status="$(jq -r '.status // "running"' <<<"$task")"
  if [[ "$final_status" == "needs_attention" ]]; then
    summary_attention=$((summary_attention + 1))
  fi
  echo "$task" >> "$tmp_ndjson"
done < <(jq -c '.[]' "$REGISTRY_PATH")

if [[ -s "$tmp_ndjson" ]]; then
  jq -s '.' "$tmp_ndjson" > "$REGISTRY_PATH"
else
  echo "[]" > "$REGISTRY_PATH"
fi

rm -f "$tmp_ndjson"

echo "Agent check complete."
echo "Checked: $summary_checked"
echo "Done: $summary_done"
echo "Retried: $summary_retried"
echo "Needs attention: $summary_attention"
