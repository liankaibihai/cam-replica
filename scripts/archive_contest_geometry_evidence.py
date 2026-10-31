"""Archive compact local validation evidence; never copy user MATs/screenshots."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--folder", default="outputs/contest_geometry_20261031")
parser.add_argument("--log", action="append", default=[], help="Explicit inspected MATLAB log relative to repository")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
folder = root / args.folder


def compact(value):
    if isinstance(value, dict):
        return {key: compact(item) for key, item in value.items()}
    if isinstance(value, list):
        if len(value) > 64:
            return {"omittedDenseArray": True, "count": len(value),
                    "source": "Full array retained in hashed local report"}
        return [compact(item) for item in value]
    return value


reports = []
report_paths = set(folder.rglob("*verification.json"))
report_paths.update(folder.rglob("auto_model_lock.json"))
for path in sorted(report_paths):
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    reports.append({"path": path.relative_to(root).as_posix(),
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "report": compact(value)})
assert reports, "No verification reports found"
artifacts = []
for path in sorted(folder.rglob("*")):
    if path.is_file() and path.suffix.lower() in {".json", ".png", ".log"}:
        artifacts.append({"path": path.relative_to(root).as_posix(),
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
logs = []
for name in args.log:
    path = (root / name).resolve()
    assert path.is_relative_to(root) and path.suffix == ".log", "Expected repository-local MATLAB log"
    content = path.read_text(encoding="utf-8-sig")
    assert content.strip(), f"Empty log: {name}"
    logs.append({"path": path.relative_to(root).as_posix(),
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                 "content": content})
out = {"date": "2026-10-31", "baseline": "2c0fe8ed043976187230f145ce4e6800613566c9",
       "reports": reports, "artifacts": artifacts,
       "inspectedLogs": logs,
       "scope": "Functional and sampled-geometry validation. Synthetic footprints are not team measurements. No RFID, continuous sweep, optimization quality or competition certification."}
(root / "data/contest_geometry_20261031.json").write_text(
    json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Archived {len(reports)} reports and {len(artifacts)} artifact hashes")
