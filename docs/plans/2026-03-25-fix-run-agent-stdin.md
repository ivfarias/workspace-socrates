# Fix run-agent.sh — Claude Prompt File via Stdin

**Goal:** Fix `scripts/run-agent.sh` so the `claude` agent branch pipes prompt content via stdin instead of passing it as a positional shell argument, which silently fails for large prompt files.

**Architecture:** One targeted change to the claude case in `run-agent.sh`. When `$prompt_file` is set, redirect the file to stdin. When only `$description` is set, pipe it via `echo`. No other agent branches are touched.

**Tech Stack:** Bash.

---

## Background

`run-agent.sh` currently does:

```bash
prompt="$(cat "$prompt_file")"
...
exec claude \
  --model "$model" \
  --permission-mode bypassPermissions \
  --print \
  "$prompt"
```

`claude --print` requires input via stdin, not as a positional argument. Large files passed as positional args silently produce no output.

The fix: when `$prompt_file` is set, use `exec claude ... < "$prompt_file"`. When only `$description` is set, use `echo "$description" | exec claude ...`.

**File to modify:** `scripts/run-agent.sh`

---

## Task 1: Fix the claude branch

### Step 1: Find the current claude case

```bash
grep -n "claude)" scripts/run-agent.sh
```

The block looks like:
```bash
claude)
    exec claude \
      --model "$model" \
      --permission-mode bypassPermissions \
      --print \
      "$prompt"
    ;;
```

### Step 2: Replace the claude case

```bash
claude)
    if [[ -n "$prompt_file" ]]; then
      exec claude \
        --model "$model" \
        --permission-mode bypassPermissions \
        --print \
        < "$prompt_file"
    else
      echo "$prompt" | exec claude \
        --model "$model" \
        --permission-mode bypassPermissions \
        --print
    fi
    ;;
```

### Step 3: Verify syntax

```bash
bash -n scripts/run-agent.sh && echo "syntax OK"
```

Expected: `syntax OK`

### Step 4: Smoke-test stdin path

```bash
echo "say: hello world" | claude --model claude-sonnet-4-6 --permission-mode bypassPermissions --print
```

Expected: response containing "hello world".

### Step 5: Commit

```bash
git add scripts/run-agent.sh
git commit -m "fix: pipe prompt file via stdin in claude agent branch of run-agent.sh

Passing large prompt files as positional args to claude --print silently
fails. Claude Code requires prompt input via stdin. Split the claude case:
- prompt_file set: exec claude ... < \"\$prompt_file\"
- description only: echo \"\$description\" | exec claude ...

Fixes silent no-output failures for plan files larger than a few KB."
```

---

## Verification

```bash
bash -n scripts/run-agent.sh && echo "syntax OK"
git log --oneline -1
```

Both must pass. Done.
