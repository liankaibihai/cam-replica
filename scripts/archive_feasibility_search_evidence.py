"""Archive compact reports and hashes from an explicit local experiment folder."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--folder", required=True)
parser.add_argument("--log", action="append", default=[])
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
folder = (root / args.folder).resolve()
assert folder.is_relative_to(root / "outputs") and folder.is_dir()


def compact(value):
    if isinstance(value, dict):
        return {key: compact(item) for key, item in value.items()}
    if isinstance(value, list):
        if len(value) > 64:
            return {"denseArrayStoredLocally": True, "count": len(value)}
        return [compact(item) for item in value]
    return value


records, artifacts, logs = [], [], []
for path in sorted(folder.rglob("*")):
    if not path.is_file() or path.suffix.lower() not in {".json", ".mat", ".png", ".m"}:
        continue
    item = {"path": path.relative_to(root).as_posix(),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    artifacts.append(item)
    if path.suffix == ".json":
        records.append({**item, "report": compact(json.loads(path.read_text(encoding="utf-8-sig")))})
for name in args.log:
    path = (root / name).resolve()
    assert path.is_relative_to(root / "local") and path.suffix == ".log"
    logs.append({"path": path.relative_to(root).as_posix(),
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                 "content": path.read_text(encoding="utf-8-sig")})
assert records, "No experiment JSON records found"
summary = {"change": "CHG-2026-10-31-014", "baselineCommit": "dada6c638590ec7013e1d36050e1c25cd9c48f63",
           "records": records, "artifacts": artifacts, "inspectedLogs": logs,
           "scope": "Independent search implementation and fixed-input comparison. Not original-app equivalence, global optimality, physical-car or competition certification."}
(root / "data/feasibility_search_20261031.json").write_text(
    json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Archived {len(records)} reports, {len(artifacts)} artifacts, {len(logs)} logs")
