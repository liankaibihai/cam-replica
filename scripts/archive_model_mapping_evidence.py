"""Condense completed local MATLAB evidence; never rewrite experiment outputs."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sources = {}


def read(relative):
    raw = (ROOT / relative).read_bytes()
    sources[relative] = hashlib.sha256(raw).hexdigest()
    return json.loads(raw.decode("utf-8-sig"))


base = "outputs/model_mapping_20261031/"
checks = {}
for relative in [
    base + "contracts/model_mapping.json",
    base + "contracts/auto_model_lock.json",
    base + "training_core/training_verification.json",
    base + "legacy_auto_contracts/verification.json",
    base + "bspline_core/verification.json",
    "outputs/review_fixes_20261031/mapping_ui/verification.json",
    "outputs/review_fixes_20261031/bspline_ui/verification.json",
]:
    checks[relative] = read(relative)

quality = []
for name in ["quality_cubic", "quality_bezier", "quality_cubic_continuation"]:
    d = read(base + name + "/summary.json")
    row = {key: d[key] for key in ["iterations", "requestedIterations", "reason",
           "evaluations", "elapsedSeconds", "verifiedFeasible", "convergencePassed",
           "physicalParametersUnchanged", "ratio", "scope"]}
    row["experiment"] = name
    row["refined8x"] = d["assessment"]["eight"]["refinedGrid"]["metrics"]
    row["numericalChecks"] = d["assessment"]["numericalChecks"]
    row["trials"] = [{k: t[k] for k in ["stage", "reason", "iterations", "requestedIterations", "routeModel"]}
                     for t in d.get("trials", [])]
    quality.append(row)

result = {
    "date": "2026-10-31", "matlab": "R2025b",
    "baseline": "9389d919d784687fad80e8062d7a58ea40ece3bc",
    "checks": checks, "quality": quality,
    "trends": read(base + "quality_trends.json"),
    "continuationCaveat": "New same-model local solve from retained cubic candidate; weights/hardware/thresholds retained, move-regularizer reference reset to continuation input. Not internal solver-state resume. This annotation is archival context, not a field retroactively added to original output.",
    "limits": ["No original-software pointwise or real-car validation in this change.",
               "Cubic and Bezier quality experiments have different initial curves; no method ranking.",
               "All quality candidates fail physical acceptance; grid stability does not imply manufacturability."],
    "sourceSHA256": sources,
}
destination = ROOT / "data/model_mapping_20261031.json"
destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(destination)
