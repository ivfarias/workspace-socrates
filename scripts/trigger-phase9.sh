#!/usr/bin/env bash
set -euo pipefail

# trigger-phase9.sh - Orchestrate Phase 9 Post-Completion Review Pipeline
# 
# This script detects tasks ready for Phase 9 (simplify review) and spawns
# the simplify workflow. It separates orchestration from monitoring logic.
#
# Workflow:
#   1. Find tasks with phase9_status = "simplify_pending"
#   2. For each: spawn simplify skill via bootstrap-task.sh
#   3. Track simplify progress in parent task
#   4. On simplify done: propagate results to parent, move to review stage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_PATH="$WORKSPACE_ROOT/.clawdbot/active-tasks.json"
LOG_DIR="$WORKSPACE_ROOT/.clawdbot/logs"

mkdir -p "$LOG_DIR"
PHASE9_LOG="$LOG_DIR/phase9.log"

log_message() {
  local msg="$1"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $msg" | tee -a "$PHASE9_LOG"
}

# Main orchestration
main() {
  if [[ ! -f "$REGISTRY_PATH" ]]; then
    return 0
  fi

  # Find all tasks with phase9_status = "simplify_pending"
  local pending_simplify=$(jq -r '.[] | select(.phase9_status == "simplify_pending") | .id' "$REGISTRY_PATH" 2>/dev/null || echo "")
  
  if [[ -z "$pending_simplify" ]]; then
    return 0
  fi

  # Process each pending simplify task
  while IFS= read -r task_id; do
    if [[ -z "$task_id" ]]; then
      continue
    fi

    log_message "Phase 9 Stage 1: Spawning simplify for task [$task_id]"
    
    # Get task details
    local task_data=$(jq --arg id "$task_id" '.[] | select(.id == $id)' "$REGISTRY_PATH")
    
    if [[ -z "$task_data" ]]; then
      log_message "ERROR: Task [$task_id] not found in registry"
      continue
    fi

    local worktree=$(echo "$task_data" | jq -r '.worktree // ""')
    local branch=$(echo "$task_data" | jq -r '.branch // ""')
    local repo_path=$(echo "$task_data" | jq -r '.repoPath // ""')

    if [[ -z "$worktree" || -z "$branch" || -z "$repo_path" ]]; then
      log_message "ERROR: Missing worktree/branch/repo for task [$task_id]"
      continue
    fi

    # Spawn simplify task
    local simplify_task_id="${task_id}-simplify"
    
    if spawn_simplify_task "$repo_path" "$simplify_task_id" "$branch" "$worktree"; then
      log_message "SUCCESS: Spawned simplify task [$simplify_task_id]"
      
      # Update parent task: mark as simplify_running
      update_task_phase9_status "$task_id" "simplify_running"
    else
      log_message "ERROR: Failed to spawn simplify task for [$task_id]"
      update_task_phase9_status "$task_id" "simplify_failed"
    fi
  done <<< "$pending_simplify"

  # Check for completed simplify tasks and propagate results
  propagate_simplify_completion

  # Check for tasks ready for Phase 9 Stage 2 (ralph-loop review)
  spawn_ralph_loop_tasks
}

spawn_simplify_task() {
  local repo_path="$1"
  local simplify_task_id="$2"
  local branch="$3"
  local worktree="$4"

  # Create completion spec for simplify task
  local spec_file="$worktree/.socrates/simplify-completion.json"
  mkdir -p "$worktree/.socrates"
  
  cat > "$spec_file" <<'EOF'
{
  "version": 1,
  "completionMode": "no-pr-spec",
  "doneCriteria": {
    "requiredChecks": ["simplify_applied"]
  },
  "checks": [
    {
      "type": "file_contains",
      "path": ".socrates/simplify-report.json",
      "pattern": "\"session_complete\": true",
      "description": "Simplify session completed and reported"
    }
  ]
}
EOF

  # Spawn simplify via bootstrap-task.sh
  if "$SCRIPT_DIR/bootstrap-task.sh" \
    --repo "$repo_path" \
    --id "$simplify_task_id" \
    --branch "$branch" \
    --agent claude \
    --phase coding \
    --description "Phase 9 Stage 1: Run simplify skill review" \
    --completion-mode no-pr-spec \
    --spec-file ".socrates/simplify-completion.json" \
    >> "$PHASE9_LOG" 2>&1; then
    return 0
  else
    return 1
  fi
}

update_task_phase9_status() {
  local task_id="$1"
  local new_status="$2"
  local current_ts=$(date +%s000)

  # Read, update, write atomically
  local tmp_file=$(mktemp)
  trap "rm -f '$tmp_file'" RETURN

  jq --arg id "$task_id" --arg phase9_status "$new_status" --argjson ts "$current_ts" \
    '.[] |= if .id == $id then .phase9_status = $phase9_status | .updatedAt = $ts else . end' \
    "$REGISTRY_PATH" > "$tmp_file"
  
  mv "$tmp_file" "$REGISTRY_PATH"
}

propagate_simplify_completion() {
  # Find tasks where <task_id>-simplify has completed
  # Update parent task: move to review_pending stage
  
  local completed_simplify=$(jq -r '.[] | select(.id | endswith("-simplify") and .status == "done") | .id' "$REGISTRY_PATH" 2>/dev/null || echo "")
  
  if [[ -z "$completed_simplify" ]]; then
    return 0
  fi

  while IFS= read -r simplify_task_id; do
    if [[ -z "$simplify_task_id" ]]; then
      continue
    fi

    # Extract parent task ID
    local parent_task_id="${simplify_task_id%-simplify}"
    
    log_message "Phase 9 Stage 2: Simplify completed for [$parent_task_id], moving to review"

    # Update parent: simplify_completed=true, move to review_pending
    local tmp_file=$(mktemp)
    trap "rm -f '$tmp_file'" RETURN

    jq --arg id "$parent_task_id" --argjson ts "$(date +%s000)" \
      '.[] |= if .id == $id then .simplify_completed = true | .phase9_status = "review_pending" | .updatedAt = $ts else . end' \
      "$REGISTRY_PATH" > "$tmp_file"
    
    mv "$tmp_file" "$REGISTRY_PATH"
  done <<< "$completed_simplify"
}

spawn_ralph_loop_tasks() {
  # Find tasks with phase9_status = "review_pending"
  # Spawn ralph-loop-coordinator skill to orchestrate review cycles
  
  local pending_review=$(jq -r '.[] | select(.phase9_status == "review_pending") | .id' "$REGISTRY_PATH" 2>/dev/null || echo "")
  
  if [[ -z "$pending_review" ]]; then
    return 0
  fi

  while IFS= read -r task_id; do
    if [[ -z "$task_id" ]]; then
      continue
    fi

    log_message "Phase 9 Stage 2: Spawning ralph-loop for task [$task_id]"
    
    # Get task details
    local task_data=$(jq --arg id "$task_id" '.[] | select(.id == $id)' "$REGISTRY_PATH")
    
    if [[ -z "$task_data" ]]; then
      log_message "ERROR: Task [$task_id] not found in registry"
      continue
    fi

    local worktree=$(echo "$task_data" | jq -r '.worktree // ""')
    local branch=$(echo "$task_data" | jq -r '.branch // ""')
    local repo_path=$(echo "$task_data" | jq -r '.repoPath // ""')

    if [[ -z "$worktree" || -z "$branch" || -z "$repo_path" ]]; then
      log_message "ERROR: Missing worktree/branch/repo for task [$task_id]"
      continue
    fi

    # Spawn ralph-loop task
    local ralph_task_id="${task_id}-ralph"
    
    if spawn_ralph_loop_task "$repo_path" "$ralph_task_id" "$branch" "$worktree"; then
      log_message "SUCCESS: Spawned ralph-loop task [$ralph_task_id]"
      
      # Update parent task: mark as review_in_progress
      update_task_phase9_status "$task_id" "review_in_progress"
    else
      log_message "ERROR: Failed to spawn ralph-loop task for [$task_id]"
      update_task_phase9_status "$task_id" "review_failed"
    fi
  done <<< "$pending_review"
}

spawn_ralph_loop_task() {
  local repo_path="$1"
  local ralph_task_id="$2"
  local branch="$3"
  local worktree="$4"

  # Create completion spec for ralph-loop task
  local spec_file="$worktree/.socrates/ralph-loop-completion.json"
  mkdir -p "$worktree/.socrates"
  
  cat > "$spec_file" <<'EOF'
{
  "version": 1,
  "completionMode": "no-pr-spec",
  "doneCriteria": {
    "requiredChecks": ["review_complete"]
  },
  "checks": [
    {
      "type": "file_contains",
      "path": ".socrates/review-report.json",
      "pattern": "\"review_signature\":",
      "description": "Ralph-loop review cycle completed with explicit signature"
    }
  ]
}
EOF

  # Spawn ralph-loop via bootstrap-task.sh
  if "$SCRIPT_DIR/bootstrap-task.sh" \
    --repo "$repo_path" \
    --id "$ralph_task_id" \
    --branch "$branch" \
    --agent claude \
    --phase coding \
    --description "Phase 9 Stage 2: Run ralph-loop deterministic review cycle" \
    --completion-mode no-pr-spec \
    --spec-file ".socrates/ralph-loop-completion.json" \
    >> "$PHASE9_LOG" 2>&1; then
    return 0
  else
    return 1
  fi
}

main "$@"
