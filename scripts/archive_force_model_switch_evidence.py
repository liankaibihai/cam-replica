"""Aggregate the hand-operated model switch contracts without changing sources."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "outputs/force_model_switch_20261031"
reports = {}
sources = []
for label, relative, expected in (
    ("forceCore", "core/verification.json", 6),
    ("forceUI", "ui/verification.json", 6),
    ("strictMapping", "regression_mapping/model_mapping.json", 4),
    ("automaticModelLock", "regression_auto_confirmed/contracts/auto_model_lock.json", 3),
    ("legacyStateUI", "regression_ui/state/verification.json", 4),
    ("legacyMappingUI", "regression_ui/mapping/verification.json", 3),
    ("bsplineUI", "regression_ui/bspline/verification.json", 10),
):
    path = FOLDER / relative
    record = json.loads(path.read_text(encoding="utf-8-sig"))
    assert len(record["checks"]) == expected, label
    reports[label] = record
    sources.append(path)

log_ids = {
    "initialUIConstruction": "944ce3cd4cac4a4baf19936d312936db",
    "coreFixtureExpectedRejectionFailed": "527a6d4258224c55a4179f9a768119e1",
    "coreFixtureSamplingFailed": "2b5a28483ad34747b05de85a053ede87",
    "corePassed": "609e872433814206b961a0c57fc76492",
    "uiBeforeAxisModesFix": "e4166ae87eb5481b8ff7fa3a7f97bd19",
    "uiFinalPassed": "db871bfdb54c405ab427ecf3adfcc4fc",
    "basicAndMappingPassedAutoFailed": "f74a91e218db454a96c8a1b256f23217",
    "restrictedAutoAssertionsPassedExitStalled": "af6e463106974121abf964fa128ff3d4",
    "restrictedUIStartupStalled": "bfb0be461b1c48b4893525880b98db0a",
    "legacyUIFinalPassed": "140d4f75e1bc4cb8b47a0eee17779a59",
    "autoFinalPassed": "2b8343ca01974beea109bae39d3d6858",
}
logs = {label: ROOT / "local" / ("matlab_" + run + ".log") for label, run in log_ids.items()}
sources += list(logs.values())
initial = logs["basicAndMappingPassedAutoFailed"].read_text(encoding="utf-8-sig")
basic = json.loads(re.search(r"RESULT (\{[^\r\n]+\})", initial).group(1))
assert basic["passed"] == basic["total"] == 12
for name, marker in (
    ("corePassed", "FORCE_MODEL_SWITCH_CORE_PASS checks=6"),
    ("uiFinalPassed", "FORCE_MODEL_SWITCH_UI_PASS checks=6"),
    ("legacyUIFinalPassed", "BSPLINE_UI_PASS cases=10"),
    ("autoFinalPassed", "AUTO_MODEL_LOCK_PASS cases=3"),
):
    assert marker in logs[name].read_text(encoding="utf-8-sig"), name
sources += [ROOT / name for name in (
    "+camdesign/mapRouteModel.m", "+camdesign/applyTrainingSettings.m", "+camdesign/rebuildRoute.m", "CamReplicaApp.m",
    "check_force_model_switch.m", "check_force_model_switch_ui.m", "check_model_mapping.m",
    "check_model_mapping_ui.m", "check_review_ui_fixes.m", "check_bspline_ui.m", "check_auto_model_lock.m",
    "outputs/model_mapping_20261031/quality_cubic/result.mat",
)]
sources += list((FOLDER / "ui").glob("*.png"))
sources += list((FOLDER / "regression_ui").rglob("*.png"))
fit = reports["forceCore"]["forcedFit"]
assert fit["forced"] and not fit["withinTolerance"] and fit["endpointConstraintsSatisfied"]
summary = {
    "change": "CHG-2026-10-31-010",
    "baselineCommit": "f06915235a977eca7939d79e370f91afb03b94eb",
    "basicChecks": basic,
    "reports": reports,
    "uniqueChecksPassed": basic["passed"] + sum(len(r["checks"]) for r in reports.values()),
    "logs": {label: path.relative_to(ROOT).as_posix() for label, path in logs.items()},
    "runnerOutcomes": {
        "newCoreAndFinalUI": "Exit 0 confirmed by executor commands.",
        "legacyUIAndAutoFinal": "Exit 0 confirmed by root; final runs use normal host access with isolated MATLAB prefs.",
        "initialRootRegression": "Basic 12 and mapping 4 passed; auto failed after derived metadata changed the locked top-level project. Fixed by keeping manual display metadata in UI. Owned stalled process terminated; wrapper exit 1, not overall pass.",
        "restrictedAutoRetry": "All 3 assertions and report passed; runner failed to exit. Owned process terminated, wrapper exit 1; subsequently rerun with normal exit 0.",
        "restrictedUI": "No test result before startup stall; owned process terminated, wrapper exit 1; subsequently rerun with normal exit 0.",
        "legacyUIWarnings": "Rank-deficient/near-singular fmincon warnings occurred in the existing short straight-line B5 functionality fixture. Assertions passed; no optimization quality claim.",
    },
    "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(sources))},
    "scope": "Manual force is an explicit reshape exception; default/automatic preservation gates and hardware remain fixed. Tests use the saved solar candidate plus analytic fixtures, not the unavailable current user MAT, and certify UI/representation behavior rather than machining or real-car precision.",
}
destination = ROOT / "data/force_model_switch_20261031.json"
destination.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Archived {summary['uniqueChecksPassed']} checks and {len(summary['sourceSHA256'])} source hashes.")
