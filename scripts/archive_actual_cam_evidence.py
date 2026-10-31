"""Archive compact actual-contact evidence; MATLAB outputs remain ignored."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "outputs/actual_cam_20261031"


def read(name):
    return json.loads((FOLDER / name).read_text(encoding="utf-8-sig"))


sources = [
    "outputs/model_mapping_20261031/quality_bezier/result.mat",
    "outputs/model_mapping_20261031/quality_cubic/result.mat",
    "outputs/actual_cam_20261031/core_verification.json",
    "outputs/actual_cam_20261031/solar_dense_verification.json",
    "outputs/actual_cam_20261031/ui/verification.json",
    "outputs/actual_cam_20261031/core_results.mat",
    "outputs/actual_cam_20261031/solar_dense_results.mat",
    "local/matlab_971ea8b0fb8d4eac8d8251b9855847e0.log",
    "local/matlab_c17b85a96763432da3a9584261bac9b0.log",
    "local/matlab_cadd6d4eeec4444283f22284a4744036.log",
    "local/matlab_64c9fd19d53543f2bd85c4e6be9633bd.log",
    "local/matlab_9dec92253e3a477cb29f27ac2574a90b.log",
    "local/matlab_725c538c807d492a947cb1ab3467a672.log",
]
core = read("core_verification.json")
dense = read("solar_dense_verification.json")
ui = read("ui/verification.json")
assert core["groupsPassed"] == 8 and ui["passed"] == 7
assert dense["closurePassed"] and not dense["geometryFeasible"]
assert dense["physicalGearRatio"] == 35 and dense["outlineUnchanged"]
summary = {
    "change": "CHG-2026-10-31-008",
    "baselineCommit": "f072cde32b482fcc5631952659e97632c62556c1",
    "core": core,
    "solarDense": dense,
    "ui": ui,
    "scope": "Independent actual polygon contact and ideal no-slip vehicle; numerical closure is not physical feasibility, original-app equivalence or measured hardware accuracy.",
    "sourceSHA256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sources},
}
destination = ROOT / "data/actual_cam_closure_20261031.json"
destination.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Archived {core['groupsPassed']} core groups, {ui['passed']} UI groups, {len(sources)} source hashes.")
