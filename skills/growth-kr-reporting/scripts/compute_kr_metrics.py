#!/usr/bin/env python3
"""Compute KR metric deltas and pace-to-target with traceable sources."""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any


@dataclass
class Point:
    csv_row: int
    dt: date
    value: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Compute KR metrics from a timeseries CSV.")
    parser.add_argument("--input", required=True, help="CSV path with date and value columns")
    parser.add_argument("--metric-name", required=True, help="Metric label for output")
    parser.add_argument("--out", required=True, help="Output JSON path")
    parser.add_argument("--target", type=float, help="Target value for the cycle")
    parser.add_argument("--cycle-start", help="Cycle start date in YYYY-MM-DD")
    parser.add_argument("--cycle-end", help="Cycle end date in YYYY-MM-DD")
    parser.add_argument("--as-of", help="As-of date in YYYY-MM-DD (default: latest available)")
    return parser.parse_args()


def parse_date(raw: str) -> date:
    return datetime.strptime(raw, "%Y-%m-%d").date()


def find_column(fieldnames: list[str], candidates: tuple[str, ...]) -> str:
    normalized = {name.strip().lower(): name for name in fieldnames}
    for candidate in candidates:
        if candidate in normalized:
            return normalized[candidate]
    raise ValueError(f"Missing required column. Expected one of: {', '.join(candidates)}")


def load_points(csv_path: Path) -> list[Point]:
    with csv_path.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            raise ValueError("CSV has no header row")

        date_col = find_column(reader.fieldnames, ("date", "day", "week", "period"))
        value_col = find_column(reader.fieldnames, ("value", "metric_value", "amount"))

        points: list[Point] = []
        for idx, row in enumerate(reader, start=2):
            raw_date = (row.get(date_col) or "").strip()
            raw_value = (row.get(value_col) or "").strip()
            if not raw_date or not raw_value:
                continue
            points.append(Point(csv_row=idx, dt=parse_date(raw_date), value=float(raw_value)))

    if not points:
        raise ValueError("No valid rows found in CSV")

    points.sort(key=lambda p: p.dt)
    return points


def pick_current_index(points: list[Point], as_of: date | None) -> int:
    if as_of is None:
        return len(points) - 1

    idx = -1
    for i, point in enumerate(points):
        if point.dt <= as_of:
            idx = i
        else:
            break

    if idx < 0:
        raise ValueError("No rows are <= --as-of date")
    return idx


def clamp(value: int, minimum: int, maximum: int) -> int:
    return max(minimum, min(value, maximum))


def main() -> None:
    args = parse_args()
    csv_path = Path(args.input)
    out_path = Path(args.out)

    points = load_points(csv_path)
    as_of = parse_date(args.as_of) if args.as_of else None

    current_idx = pick_current_index(points, as_of)
    current = points[current_idx]
    previous = points[current_idx - 1] if current_idx > 0 else None

    delta_abs = current.value - previous.value if previous else None
    delta_pct = (delta_abs / previous.value * 100.0) if previous and previous.value != 0 else None

    claims: dict[str, Any] = {
        "current_value": {
            "value": current.value,
            "unit": "raw",
            "source": {
                "path": str(csv_path),
                "csv_row": current.csv_row,
                "date": current.dt.isoformat(),
            },
        }
    }

    if previous:
        claims["previous_value"] = {
            "value": previous.value,
            "unit": "raw",
            "source": {
                "path": str(csv_path),
                "csv_row": previous.csv_row,
                "date": previous.dt.isoformat(),
            },
        }

    if delta_abs is not None:
        claims["delta_abs"] = {
            "value": delta_abs,
            "unit": "raw",
            "formula": "current_value - previous_value",
            "depends_on": ["current_value", "previous_value"],
        }

    if delta_pct is not None:
        claims["delta_pct"] = {
            "value": delta_pct,
            "unit": "percent",
            "formula": "(current_value - previous_value) / previous_value * 100",
            "depends_on": ["current_value", "previous_value"],
        }

    status = {
        "value": "Blocked - missing target definition",
        "rule": "status requires target and cycle window",
    }

    if args.target is not None:
        claims["progress_to_target_pct"] = {
            "value": (current.value / args.target * 100.0) if args.target != 0 else None,
            "unit": "percent",
            "formula": "current_value / target * 100",
            "depends_on": ["current_value"],
            "target": args.target,
        }
        claims["remaining_to_target"] = {
            "value": args.target - current.value,
            "unit": "raw",
            "formula": "target - current_value",
            "depends_on": ["current_value"],
            "target": args.target,
        }

        if args.cycle_start and args.cycle_end:
            cycle_start = parse_date(args.cycle_start)
            cycle_end = parse_date(args.cycle_end)
            as_of_date = current.dt
            total_days = (cycle_end - cycle_start).days + 1
            if total_days <= 0:
                raise ValueError("cycle-end must be >= cycle-start")

            elapsed_days = clamp((as_of_date - cycle_start).days + 1, 0, total_days)
            remaining_days = max((cycle_end - as_of_date).days, 0)
            expected_value_by_now = args.target * (elapsed_days / total_days)
            remaining = args.target - current.value
            required_daily_pace = remaining / remaining_days if remaining_days > 0 else None

            claims["expected_value_by_now"] = {
                "value": expected_value_by_now,
                "unit": "raw",
                "formula": "target * (elapsed_days / total_days)",
                "depends_on": ["current_value"],
                "target": args.target,
                "cycle_start": cycle_start.isoformat(),
                "cycle_end": cycle_end.isoformat(),
                "elapsed_days": elapsed_days,
                "total_days": total_days,
            }

            claims["required_daily_pace"] = {
                "value": required_daily_pace,
                "unit": "raw_per_day",
                "formula": "(target - current_value) / remaining_days",
                "depends_on": ["current_value"],
                "target": args.target,
                "remaining_days": remaining_days,
            }

            status_value = "On track" if current.value >= expected_value_by_now else "Off track"
            status = {
                "value": status_value,
                "rule": "On track if current_value >= expected_value_by_now; Off track otherwise",
                "depends_on": ["current_value", "expected_value_by_now"],
            }

    output = {
        "metric_name": args.metric_name,
        "as_of": current.dt.isoformat(),
        "claims": claims,
        "status": status,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
