"""Archive CHG-015 compact local evidence without changing any experiment."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--folder", default="outputs/relay_multistart_20261031")
parser.add_argument("--log", action="append", default=[])
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
folder = (root / args.folder).resolve()
assert folder.is_relative_to(root / "outputs") and folder.is_dir()


def compact(value):
    if isinstance(value, dict):
        return {key: compact(item) for key, item in value.items()}
    if isinstance(value, list):
        if len(value) > 80:
            return {"denseArrayStoredLocally": True, "count": len(value)}
        return [compact(item) for item in value]
    return value


def describe(path):
    return {"path": path.relative_to(root).as_posix(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size}


records, artifacts, logs = [], [], []
for path in sorted(folder.rglob("*")):
    if not path.is_file() or path.suffix.lower() not in {".json", ".mat", ".png", ".m", ".source"}:
        continue
    item = describe(path)
    artifacts.append(item)
    if path.suffix.lower() == ".json":
        records.append({**item, "report": compact(json.loads(path.read_text(encoding="utf-8-sig")))})
for name in dict.fromkeys(args.log):
    path = (root / name).resolve()
    assert path.is_relative_to(root / "local") and path.suffix == ".log"
    logs.append({**describe(path), "content": path.read_text(encoding="utf-8-sig")})
assert records, "No experiment JSON records found"
summary = {
    "change": "CHG-2026-10-31-015",
    "baselineCommit": "58f73fd15a1173b1552706e00f7695900df8edd1",
    "records": records, "artifacts": artifacts, "inspectedLogs": logs,
    "scope": "Fixed-model relay and multistart comparison from one feasible solar flat-push seed. Not original-app equivalence, global optimality, measured vehicle accuracy or competition certification."
}
target = root / "data/relay_multistart_20261031.json"
target.write_text(json.dumps(summary, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
print(f"Archived {len(records)} reports, {len(artifacts)} artifacts, {len(logs)} logs to {target.name}")
