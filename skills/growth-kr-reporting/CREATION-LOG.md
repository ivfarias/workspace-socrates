# Creation Log: growth-kr-reporting

## Context
New skill requested to support Growth KR reporting beyond paid media, while enforcing strict evidence discipline:
- no mental math for calculations
- no assumptions when data is missing
- all insights tied to sources
- explicit clarification questions when inputs are incomplete

## RED Phase (Baseline Without Skill)

### Scenario 1: Missing target/cycle, forced status
- Prompt asked for status and update with partial data.
- Baseline behavior: assistant still returned `On track` using implicit interpretation.
- Failure: status inference without explicit target and cycle definition.

### Scenario 2: Missing trend/drivers, forced decision section
- Prompt provided only current MRR and target, missing previous value and channel mix.
- Baseline behavior: assistant created operational decisions and weekly breakdown assumptions.
- Failure: invented structure and recommendations without source evidence.

### Scenario 3: ARPA driver explanation from minimal table
- Prompt asked for ARPA by channel and drivers.
- Baseline behavior: assistant added causal narratives (lead quality, offer structure) not present in input data.
- Failure: unsupported causal claims.

## GREEN Phase (First Skill Version)
- Added script-only calculation rule, source requirements, and no-assumption policy.
- Validation test A passed: assistant blocked status when target/cycle were missing.
- Validation test B failed: under pressure ("do quick mental math"), assistant still produced numbers.

## REFACTOR Phase
Meta-test asked the violating assistant how to make the skill unambiguous.

Changes applied:
1. Added `Absolute Enforcement (Non-Overridable)` section.
2. Added `Hard Stop Conditions` (no numeric output before script execution).
3. Added explicit refusal template.
4. Added final compliance checklist.
5. Expanded description to include pressure symptoms (quick math, assumptions, unsourced insights).

## VERIFY GREEN (After Refactor)
Repeated pressure scenario ("do not run script, do mental math") with mandatory skill.

Result:
- Assistant refused numeric output.
- Assistant returned script command + missing parameters only.
- No computed numbers were emitted.

Status: PASS.

## Outcome
Skill is now aligned with requested operating principles and includes a reusable script tool:
- `SKILL.md`
- `scripts/compute_kr_metrics.py`

## Date
2026-02-18

---

## Orchestrator Upgrade Iteration
Date: 2026-02-18

### Request
Evolve the skill into an orchestrator that:
- reads `/Users/ivanfarias/clawd/scripts/metrics_map.json`
- selects required scripts per KR
- spawns parallel subagents per analysis block
- consolidates subagent markdown outputs into one final report
- loops on missing data (fetch subagent vs user question)

### RED Phase (Baseline Against Previous Version)
Baseline test with previous skill version showed orchestration behavior was not explicit and deterministic enough:
- no mandatory selector step over `metrics_map.json`
- no explicit subagent artifact contract (`subagents/<slug>.md`)
- no formal missing-data loop policy (`fetchable` vs `external_input`)
- no explicit final consolidation artifact path under run-scoped folder

### GREEN Changes
1. Refactored `SKILL.md` to orchestration-first workflow:
   - run setup with `run_id`
   - script discovery from metrics map
   - parallel subagent fan-out by analysis block
   - missing-data loop
   - final consolidation artifact
2. Added helper selector script:
   - `scripts/select_metric_scripts.py`
   - loads metrics map and selects scripts by KR id
   - resolves execution commands with absolute script paths
3. Added hard-stop conditions for map loading and missing mappings.

### REFACTOR Fixes
Found and fixed two selector loopholes:
1. KR substring bug:
   - `O2.1.2` incorrectly matched `O2.1.2.1` and `O2.1.2.2`.
   - fix: exact KR regex with boundary guard.
2. Unknown KR false-positive bug:
   - unknown KRs still returned unrelated scripts via generic heuristics.
   - fix: only exact KR matches by default; query fallback only when query terms are provided.

### VERIFY GREEN
Validation scenario A (orchestrator plan):
- assistant cited selector command
- assistant used map path
- assistant delegated by analysis blocks with subagent markdown outputs
- assistant described missing-data loop and final consolidation file

Validation scenario B (missing mapping hard-stop):
- for `KR Z9.9.9`, selector returned `missing_mapping`
- assistant blocked completion and asked for map update/user input

Status: PASS.

---

## Final Report Contract Iteration
Date: 2026-02-18

### Request
Ensure the orchestrator always produces a final report that answers mandatory questions for the full "Vender o Metodo" KR set, including associated metrics (example: Paid Media AD5 must include signups, installs, cost, clicks, impressions).

### RED Phase (Gap Found)
Baseline orchestration plan could satisfy these requirements only when explicitly prompted by the user in that exact message. The requirement was not fully encoded as a non-optional skill contract.

Main gaps:
- mandatory 5-KR scope not explicit enough
- no strict question matrix per KR in the skill
- associated-metric bundle requirement not enforced as part of script planning
- no explicit hard-stop behavior for fallback-only KR mapping

### GREEN Changes
1. Updated `SKILL.md` with mandatory final-report contract:
   - required 5 KRs for "Vender o Metodo"
   - associated metrics by KR
   - mandatory question checklist by KR
   - mandatory final artifact path `docs/analytics/runs/<run_id>/final-analysis.md`
2. Updated selector `scripts/select_metric_scripts.py`:
   - KR associated-metric bundles (`KR_ASSOCIATED_METRICS`)
   - bundle coverage reporting (`covered_metric_bundle`, `missing_metric_bundle`)
   - top-level `coverage_gaps`
   - auto KR-intent query tokens to improve selection of supporting scripts

### REFACTOR Fixes
1. Corrected KR fallback detection:
   - added `mapping_mode` (`exact`, `query_fallback`, `none`)
   - top-level `fallback_krs` list
2. Tightened metric coverage to use script semantics (`description`, `output_fields`, `metrics_included`) instead of generic usage text.
3. Updated skill hard-stop/checklist to treat unresolved `fallback_krs` as blocking.

### VERIFY GREEN
Validation A (`KR O2.1.1`):
- selector returns `mapping_mode: exact`
- associated metric bundle coverage is explicit

Validation B (`KR T2.1` currently without exact map entry):
- selector returns `mapping_mode: query_fallback`
- `fallback_krs` populated
- skill contract now requires blocking until resolved

Validation C (subagent behavior):
- subagent now returns contract including 5 KRs, O2.1.1 required metrics, mandatory questions, final artifact path, and fallback handling.

Status: PASS.
