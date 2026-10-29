"""Run the installed reader with bounded networking and verify real outputs.

No browser cookies, disabled TLS verification, or paid API fallback is used.
The upstream CLI may exit 0 when an individual item fails; check its summary.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys
import tomllib


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("--mode", choices=("subtitles", "frames", "balanced"), default="subtitles")
    parser.add_argument("--browser-transport", action="store_true")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    skill = Path.home() / ".codex/skills/bilibili-video-reader/scripts/read_bilibili_video.py"
    config = Path.home() / ".codex/config.toml"
    settings = tomllib.loads(config.read_text(encoding="utf-8")) if config.exists() else {}
    for entry in settings.get("skills", {}).get("config", []):
        if Path(entry.get("path", "")).resolve() == (skill.parent.parent / "SKILL.md").resolve() and not entry.get("enabled", True):
            parser.error("Bilibili Video Reader is disabled. Use inspect_local_video.py for local files.")
    if not skill.is_file():
        parser.error(f"Install the bilibili-video-reader skill first: {skill}")
    spec = importlib.util.spec_from_file_location("installed_bilibili_reader", skill)
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    original_options = reader.base_ydl_options

    def bounded_options():
        result = original_options()
        result.update(socket_timeout=20, retries=1, extractor_retries=1)
        if args.browser_transport:
            from yt_dlp.networking.impersonate import ImpersonateTarget
            result["impersonate"] = ImpersonateTarget.from_str("chrome")
        return result

    reader.base_ydl_options = bounded_options
    output = Path(__file__).resolve().parents[1] / "local/video_research"
    output.mkdir(parents=True, exist_ok=True)
    allocated_runs = []
    upstream_build_directory = reader.build_run_directory

    def record_run_directory(*values, **options):
        path = upstream_build_directory(*values, **options)
        allocated_runs.append(path)
        return path

    reader.build_run_directory = record_run_directory
    upstream_args = [str(skill), args.url, "--auto-subtitles", "--transcription-backend", "local", "--out-dir", str(output)]
    if args.mode == "frames":
        upstream_args += ["--extract-frames"]
    elif args.mode == "balanced":
        upstream_args += ["--balanced-read"]
    previous_argv = sys.argv
    try:
        sys.argv = upstream_args
        code = reader.main()
    finally:
        sys.argv = previous_argv
    if code:
        return code
    if len(allocated_runs) != 1:
        print("Expected exactly one new run summary.", file=sys.stderr)
        return 2
    summary_path = allocated_runs[0] / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    reports = []
    for item in summary.get("items", []):
        transcript = item.get("transcript_path")
        has_text = bool(transcript and Path(transcript).is_file() and Path(transcript).stat().st_size)
        frames = [p for p in item.get("frame_files", []) if Path(p).is_file()]
        usable = not item.get("error") and (bool(frames) if args.mode == "frames" else has_text)
        if args.mode == "balanced":
            usable = usable and bool(frames)
        reports.append({"title": item.get("title"), "source_url": item.get("source_url"),
                        "has_transcript": has_text, "frame_count": len(frames),
                        "usable_for_requested_mode": usable, "error": item.get("error")})
    passed = bool(reports) and all(r["usable_for_requested_mode"] for r in reports)
    verification = {"summary_path": str(summary_path), "mode": args.mode,
                    "browser_transport": args.browser_transport, "passed": passed, "items": reports}
    (summary_path.parent / "checked_result.json").write_text(
        json.dumps(verification, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(verification, ensure_ascii=False, indent=2))
    return 0 if passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
