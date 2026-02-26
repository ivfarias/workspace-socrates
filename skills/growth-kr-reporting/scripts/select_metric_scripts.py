#!/usr/bin/env python3
"""Select mapped analytics scripts by KR id from metrics_map.json."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_MAP_PATH = "/Users/ivanfarias/clawd/scripts/metrics_map.json"

KR_ASSOCIATED_METRICS: dict[str, list[str]] = {
    "T2.1": ["mrr", "assinaturas iniciadas", "app", "web", "channel"],
    "O2.1.1": ["signups", "installs", "cost", "clicks", "impressions"],
    "O2.1.2": ["mrr", "novos", "web", "app", "channel"],
    "O2.1.2.1": ["assinaturas", "web", "reativacoes", "novas", "channel", "country"],
    "O2.1.2.2": ["arpa", "web", "channel", "country"],
}


@dataclass
class Candidate:
    item: dict[str, Any]
    score: int
    reasons: list[str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Select analytics scripts by KR from metrics map")
    parser.add_argument("--metrics-map", default=DEFAULT_MAP_PATH, help="Path to metrics_map.json")
    parser.add_argument("--kr", action="append", required=True, help="KR id (e.g., O2.1.1). Repeatable.")
    parser.add_argument("--query", action="append", default=[], help="Optional intent keywords")
    parser.add_argument("--top-n", type=int, default=8, help="Max scripts per KR")
    parser.add_argument("--out", required=True, help="Output JSON path")
    return parser.parse_args()


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def tokenize(text: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", normalize(text)))


def resolve_execution(item: dict[str, Any]) -> str:
    execution = str(item.get("execution", "")).strip()
    script_path = str(item.get("script_path", "")).strip()
    if not execution:
        return f"python3 {script_path}" if script_path else ""

    script_name = Path(script_path).name if script_path else ""
    if script_name:
        execution = execution.replace(f"python3 {script_name}", f"python3 {script_path}")

    if "venv/bin/activate" in execution and script_path:
        scripts_dir = str(Path(script_path).parent)
        execution = execution.replace("source venv/bin/activate", f"cd {scripts_dir} && source venv/bin/activate")

    return execution


def score_item(item: dict[str, Any], kr_id: str, query_tokens: set[str]) -> Candidate:
    usage = str(item.get("usage", ""))
    name = str(item.get("name", ""))
    description = str(item.get("description", ""))

    score = 0
    reasons: list[str] = []

    usage_norm = normalize(usage)
    kr_pattern = re.compile(rf"\bkr\s+{re.escape(normalize(kr_id))}(?![\d.])")
    if kr_pattern.search(usage_norm):
        score += 100
        reasons.append("usage_exact_kr_match")

    all_text = " ".join([name, description, usage, " ".join(item.get("metrics_included", []))])
    tokens = tokenize(all_text)
    token_overlap = sorted(query_tokens & tokens)
    if token_overlap:
        score += min(len(token_overlap) * 5, 35)
        reasons.append(f"query_overlap:{','.join(token_overlap)}")

    decomposition_markers = ("by channel", "by country", "campaign", "ad group", "funnel")
    lower_name = normalize(name)
    if any(marker in lower_name for marker in decomposition_markers):
        score += 10
        reasons.append("decomposition_view")

    weekly_monthly_markers = ("weekly", "monthly", "overall")
    if any(marker in normalize(description) for marker in weekly_monthly_markers):
        score += 3
        reasons.append("trend_view")

    return Candidate(item=item, score=score, reasons=reasons)


def classify_role(name: str) -> str:
    lowered = normalize(name)
    if any(token in lowered for token in ("by channel", "campaign", "ad group", "funnel", "by country")):
        return "decomposition"
    if any(token in lowered for token in ("weekly", "monthly", "overall")):
        return "core"
    return "supporting"


def load_metrics(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    metrics = data.get("metrics")
    if not isinstance(metrics, list):
        raise ValueError("metrics_map.json must contain a 'metrics' array")
    return [m for m in metrics if isinstance(m, dict)]


def metric_coverage(required: list[str], scripts: list[dict[str, Any]]) -> tuple[list[str], list[str]]:
    if not required:
        return [], []

    corpus = " ".join(
        [
            " ".join(
                [
                    str(script.get("name", "")),
                    str(script.get("description", "")),
                    " ".join(script.get("output_fields", [])),
                    " ".join(script.get("metrics_included", [])),
                ]
            )
            for script in scripts
        ]
    )
    corpus_norm = normalize(corpus)

    covered: list[str] = []
    missing: list[str] = []
    for item in required:
        if normalize(item) in corpus_norm:
            covered.append(item)
        else:
            missing.append(item)
    return covered, missing


def select_for_kr(metrics: list[dict[str, Any]], kr_id: str, query_tokens: set[str], top_n: int) -> dict[str, Any]:
    scored = [score_item(item, kr_id, query_tokens) for item in metrics]

    exact = [cand for cand in scored if "usage_exact_kr_match" in cand.reasons]
    exact.sort(key=lambda c: c.score, reverse=True)

    selected_candidates: list[Candidate] = []
    selected_keys: set[tuple[str, str]] = set()

    def add_candidate(candidate: Candidate) -> None:
        key = (
            str(candidate.item.get("name", "")),
            str(candidate.item.get("script_path", "")),
        )
        if key in selected_keys:
            return
        selected_candidates.append(candidate)
        selected_keys.add(key)

    for candidate in exact:
        if len(selected_candidates) >= top_n:
            break
        add_candidate(candidate)

    query_matches = [
        cand
        for cand in scored
        if any(reason.startswith("query_overlap:") for reason in cand.reasons)
        and "usage_exact_kr_match" not in cand.reasons
    ]
    query_matches.sort(key=lambda c: c.score, reverse=True)

    required_bundle = KR_ASSOCIATED_METRICS.get(kr_id, [])

    def materialize(candidates: list[Candidate]) -> list[dict[str, Any]]:
        scripts: list[dict[str, Any]] = []
        for candidate in candidates:
            item = candidate.item
            script_path = str(item.get("script_path", "")).strip()
            scripts.append(
                {
                    "name": item.get("name"),
                    "usage": item.get("usage"),
                    "description": item.get("description"),
                    "data_source": item.get("data_source"),
                    "script_path": script_path,
                    "execution": item.get("execution"),
                    "execution_resolved": resolve_execution(item),
                    "output_fields": item.get("output_fields", []),
                    "metrics_included": item.get("metrics_included", []),
                    "role": classify_role(str(item.get("name", ""))),
                    "score": candidate.score,
                    "reasons": candidate.reasons,
                }
            )
        return scripts

    current_scripts = materialize(selected_candidates)
    _, missing_bundle = metric_coverage(required_bundle, current_scripts)

    for candidate in query_matches:
        if len(selected_candidates) >= top_n:
            break
        if not missing_bundle:
            break
        add_candidate(candidate)
        current_scripts = materialize(selected_candidates)
        _, missing_bundle = metric_coverage(required_bundle, current_scripts)

    if not selected_candidates and query_tokens:
        for candidate in query_matches:
            if len(selected_candidates) >= top_n:
                break
            add_candidate(candidate)

    scripts = materialize(selected_candidates)
    covered_bundle, missing_bundle = metric_coverage(required_bundle, scripts)
    if scripts and exact:
        mapping_mode = "exact"
    elif scripts:
        mapping_mode = "query_fallback"
    else:
        mapping_mode = "none"

    return {
        "kr_id": kr_id,
        "mapping_mode": mapping_mode,
        "required_metric_bundle": required_bundle,
        "covered_metric_bundle": covered_bundle,
        "missing_metric_bundle": missing_bundle,
        "selected_count": len(scripts),
        "scripts": scripts,
        "status": "ok" if scripts else "missing_mapping",
    }


def main() -> None:
    args = parse_args()
    map_path = Path(args.metrics_map)
    output_path = Path(args.out)

    metrics = load_metrics(map_path)
    global_query_tokens = tokenize(" ".join(args.query))

    selections: list[dict[str, Any]] = []
    for kr_id in args.kr:
        default_kr_tokens = tokenize(" ".join(KR_ASSOCIATED_METRICS.get(kr_id, [])))
        effective_query_tokens = global_query_tokens | default_kr_tokens
        selections.append(select_for_kr(metrics, kr_id, effective_query_tokens, args.top_n))

    missing = [entry["kr_id"] for entry in selections if entry["status"] != "ok"]
    fallback_krs = [entry["kr_id"] for entry in selections if entry.get("mapping_mode") == "query_fallback"]
    coverage_gaps = [
        {
            "kr_id": entry["kr_id"],
            "missing_metric_bundle": entry["missing_metric_bundle"],
        }
        for entry in selections
        if entry.get("missing_metric_bundle")
    ]

    result = {
        "metrics_map_path": str(map_path),
        "requested_krs": args.kr,
        "query": args.query,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "selections": selections,
        "missing_krs": missing,
        "fallback_krs": fallback_krs,
        "coverage_gaps": coverage_gaps,
        "status": "ok" if not missing else "missing_mapping",
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
