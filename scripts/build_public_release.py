"""Build a reviewed public tree without altering the development checkout.

Usage: python scripts/build_public_release.py --output ../cam-public-staging
The destination must be absent or empty. Only tracked production files and
packaging/public templates are copied; local evidence and history stay out.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {
    "+camdesign/firstGenerationCam.m",
    "+camdesign/bezierCurve.m",
    "+camdesign/video251Features.m",
}
ENTRY = {"CamReplicaApp.m", "launch_cam_app.m", "migrate_foreground_execution.m",
         "repair_cam_app_callbacks.m"}
DATA = {"2027_solar_course.json", "2027_biomass_course.json", "team_solar_design_20261031.json"}


def build(destination):
    destination = destination.resolve()
    if destination == ROOT or ROOT in destination.parents:
        raise ValueError("Release destination must be outside the development checkout")
    if destination.exists() and any(destination.iterdir()):
        raise ValueError("Release destination must be absent or empty")
    destination.mkdir(parents=True, exist_ok=True)
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    sources = [p for p in tracked if p not in EXCLUDED and
               (p.startswith("+camdesign/") and p.endswith(".m") or p in ENTRY or
                "/" not in p and p.startswith("cam_") and p.endswith(".m"))]
    for name in sources:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((ROOT / name).read_bytes().replace(b"\r\n", b"\n"))
    for name in sorted(DATA):
        obj = json.loads((ROOT / "data" / name).read_text(encoding="utf-8-sig"))
        if name.startswith("team_"):
            obj = {"source": "Maintainer-provided design example; not measured hardware",
                   "sha256": obj["sha256"], "params": obj["params"], "asBuiltMeasured": False}
        target = destination / "data" / name
        target.parent.mkdir(exist_ok=True)
        target.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    template = ROOT / "packaging" / "public"
    for source in template.rglob("*"):
        if source.is_file():
            target = destination / source.relative_to(template)
            if target.exists():
                raise ValueError(f"Template overwrites production source: {target.name}")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes().replace(b"\r\n", b"\n"))
    required = ["README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "tests/smoke_test.m"]
    assert all((destination / x).is_file() for x in required), "Incomplete public templates"
    # Verify every literal package call resolves inside the distributed tree.
    unresolved = set()
    private = []
    for source in destination.rglob("*"):
        if not source.is_file():
            continue
        content = source.read_text(encoding="utf-8-sig")
        if re.search(r"(?<![A-Za-z0-9])[A-Za-z]:[/\\]|许昊阳|22416|01a18[0-9a-f-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN .*PRIVATE KEY", content):
            private.append(str(source.relative_to(destination)))
        if source.suffix == ".m":
            for function in re.findall(r"camdesign\.([A-Za-z]\w*)", content):
                if not (destination / "+camdesign" / (function + ".m")).exists():
                    unresolved.add(function)
    assert not private, f"Private path or credential-like content: {private}"
    assert not unresolved, f"Missing production dependency: {sorted(unresolved)}"
    files = {p.relative_to(destination).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in sorted(destination.rglob("*")) if p.is_file()}
    manifest = {"sourceCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
                "excludedCompatibilityModules": sorted(EXCLUDED), "files": files}
    (destination / "RELEASE_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"files": len(files), "packageDependenciesResolved": True,
                      "privatePatternScanPassed": True, "destination": str(destination)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args().output)
