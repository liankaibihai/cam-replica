"""Transcribe a local input manifest with one cached Whisper CPU model.

No model download, website access, or Bilibili skill invocation is performed.
Outputs are machine-generated; mathematical statements need visual checking.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=2, choices=(1, 2))
    parser.add_argument("--cpu-threads", type=int, default=4, choices=range(1, 17))
    parser.add_argument("--initial-prompt", default=None)
    parser.add_argument("--condition-on-previous-text", action="store_true")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    if not (args.model / "model.bin").is_file():
        parser.error("A complete cached model is required.")
    from faster_whisper import WhisperModel
    from local_video_audio import decode_audio
    from transcript_quality import inspect_transcript
    model = WhisperModel(str(args.model.resolve()), device="cpu", compute_type="int8",
                         cpu_threads=args.cpu_threads, num_workers=args.workers, local_files_only=True)
    records = json.loads(args.manifest.read_text(encoding="utf-8"))

    def transcribe(record):
        output = args.manifest.parent / Path(record["name"]).stem / "asr"
        output.mkdir(parents=True, exist_ok=True)
        try:
            # PyAV 19 removed metadata_errors, which faster-whisper 1.2.1's
            # file decoder still passes. Decode through the current API first.
            samples = decode_audio(record["file"])
            segments, info = model.transcribe(samples, language="zh", vad_filter=True, beam_size=3,
                                              initial_prompt=args.initial_prompt,
                                              condition_on_previous_text=args.condition_on_previous_text)
            rows = []
            partial = output / "transcript.partial.jsonl"
            with partial.open("w", encoding="utf-8") as log:
                for segment in segments:
                    row = {"start": round(segment.start, 2), "end": round(segment.end, 2),
                           "text": segment.text.strip()}
                    rows.append(row)
                    log.write(json.dumps(row, ensure_ascii=False) + "\n"); log.flush()
                    if len(rows) % 50 == 0:
                        print(f"{record['name']}: {segment.end:.0f} / {info.duration:.0f} s", flush=True)
            quality = inspect_transcript(rows, info.duration)
            result = {"machine_generated": True, "model": str(args.model.resolve()), "beam_size": 3,
                      "source_sha256": record["sha256"], "duration_seconds": info.duration,
                      "language": info.language, "cpu_threads": args.cpu_threads,
                      "initial_prompt": args.initial_prompt,
                      "condition_on_previous_text": args.condition_on_previous_text,
                      "quality_check": quality, "segments": rows}
            (output / "transcript.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            (output / "transcript.txt").write_text(
                "\n".join(f"[{r['start']:.2f}-{r['end']:.2f}] {r['text']}" for r in rows), encoding="utf-8")
            partial.unlink()
            print(f"{record['name']}: completed {len(rows)} segments, QA passed={quality['passed']}", flush=True)
            return {"name": record["name"], "completed": True, "segment_count": len(rows),
                    "qa_passed": quality["passed"]}
        except Exception as error:
            print(f"{record['name']}: failed ({type(error).__name__})", flush=True)
            return {"name": record["name"], "completed": False, "error": str(error)}

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(transcribe, records))
    summary_name = "asr_summary.json" if args.manifest.stem == "inputs" else args.manifest.stem + "_asr_summary.json"
    (args.manifest.parent / summary_name).write_text(
        json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0 if all(r["completed"] and r.get("qa_passed", False) for r in results) else 2


if __name__ == "__main__":
    raise SystemExit(main())
