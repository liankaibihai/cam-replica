"""Read-only aggregation of the Bezier precision and paired solver evidence."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "outputs/bezier_precision_20261031"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


records = []
sources = [FOLDER / "diagnosis.json"]
sources += [ROOT / "+camdesign" / name for name in (
    "independentBezierBasis.m", "bezierRoute.m", "routeGeometry.m", "route.m",
    "analyticCamMotion.m", "quinticHermitePP.m", "camProfile.m", "simulate.m",
)]
sources.append(ROOT / "local/bezier_precision_baseline.zip")
sources += [ROOT / "local" / ("matlab_" + run + ".log") for run in (
    "f9261c6824124e6aae1aaf4c543bd1f3", "b6b61cecf1e84c649a7c959870346d89",
    "c4eb50f137c842d6ab9072cf5239629f", "3aecc6d7123549009076fdc1d46e97fb",
    "de52722145a34f5eaee3c2d41801c5cc", "8bf4c011b317423fbd1ff61cf9f4a7c1",
    "1ba1ff000ef14f1ea759e824a342c363", "508c4a030a784418a726bc80ee9d44a9",
    "a44834b3a1934d43acd7d70a3ee15e63", "d7c2e562662c41b5940a5f6c402b8cd0",
    "bd91cb5b7d244a88b5b30238bfe0be56", "e4215c9303d64c7c9698268beec3b17f",
    "9e85ecf7188c47989d1f1d2d8bc0aa7c",
)]
for variant in ("baseline", "improved"):
    for stage in ("primary", "continuation"):
        folder = FOLDER / "quality" / variant
        if stage == "continuation":
            folder /= stage
        for label in ("quality34", "paired35"):
            path = folder / (label + ".json")
            item = read(path)
            assert item["parametersUnchanged"]
            assert item["protocol"]["physicalGearRatio"] == 35
            assert item["protocol"]["requestedIterations"] == 600
            item["protocol"].setdefault("stage", stage)
            assert item["protocol"]["stage"] == stage
            records.append(item)
            sources += [path, path.with_suffix(".mat")]
            sources.append(Path(item["protocol"]["sourceFile"]))

for label in ("quality34", "paired35"):
    pair = [r["protocol"] for r in records if r["protocol"]["label"] == label and r["protocol"]["stage"] == "primary"]
    for field in ("sourceFile", "requestedIterations", "maxFunctionEvaluations", "maxSeconds", "differenceStepMM", "regularizationWeight", "grid", "routeModel", "degree", "nodes", "physicalGearRatio"):
        assert pair[0][field] == pair[1][field], (label, field)

contracts = {}
for relative in ("core/verification.json", "actual_density/verification.json", "actual_core/core_verification.json", "actual_ui/verification.json", "mapping/model_mapping.json"):
    path = FOLDER / relative
    contracts[relative] = read(path)
    sources.append(path)

summary = {
    "change": "CHG-2026-10-31-009",
    "baselineCommit": "100c44df3b2e2a15bc9fc438bb0eebc5d7949a4f",
    "diagnosis": read(FOLDER / "diagnosis.json"),
    "contracts": contracts,
    "quality": records,
    "totalRequestedIterations": sum(r["protocol"]["requestedIterations"] for r in records),
    "totalActualIterations": sum(r["iterations"] for r in records),
    "totalModelAttempts": sum(r["modelAttempts"] for r in records),
    "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(sources))},
    "scope": "Fixed-curve numerical accuracy and two paired saved solar Bezier starts with same budget. Continuations start from their own primary outputs. Does not certify original-app equivalence, globally optimal designs or real-car accuracy; concurrent wall times are not a speed ranking.",
}
destination = ROOT / "data/bezier_precision_20261031.json"
destination.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Archived {len(records)} solver runs, {summary['totalActualIterations']} iterations, {summary['totalModelAttempts']} model attempts.")
