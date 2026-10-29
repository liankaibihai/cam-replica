"""Extract timestamped frames or transcribe cached media locally.

Uses PyAV (included with faster-whisper) when standalone FFmpeg is unavailable.
ASR is machine-generated evidence; verify technical terms against the frames.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("media", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--seconds", nargs="+", type=float)
    parser.add_argument("--transcribe", action="store_true")
    parser.add_argument("--model", default="base")
    args = parser.parse_args()
    if bool(args.seconds) == args.transcribe:
        parser.error("Choose exactly one of --seconds or --transcribe.")
    sys.stdout.reconfigure(encoding="utf-8")
    args.output.mkdir(parents=True, exist_ok=True)
    if args.seconds:
        import av
        entries = []
        with av.open(str(args.media)) as container:
            video = container.streams.video[0]
            for second in args.seconds:
                if second < 0:
                    parser.error("Frame timestamps must be nonnegative.")
                container.seek(int(second / float(video.time_base)), stream=video)
                frame = next(f for f in container.decode(video) if f.time >= second)
                path = args.output / f"frame_{int(second * 1000):09d}ms.png"
                with av.open(str(path), mode="w", format="image2") as destination:
                    stream = destination.add_stream("png", rate=1)
                    stream.width, stream.height, stream.pix_fmt = frame.width, frame.height, "rgb24"
                    for packet in stream.encode(frame.reformat(format="rgb24")):
                        destination.mux(packet)
                    for packet in stream.encode():
                        destination.mux(packet)
                entries.append({"requested_seconds": second, "actual_seconds": frame.time,
                                "path": str(path.resolve())})
                print(f"Frame: {frame.time:.3f} s", flush=True)
        (args.output / "frames.json").write_text(
            json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
        return
    root = Path(__file__).resolve().parents[1]
    os.environ["HF_HOME"] = str(root / "local/bilibili_models")
    os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN"] = "1"
    os.environ.setdefault("HF_HUB_DOWNLOAD_TIMEOUT", "20")
    os.environ.setdefault("HF_HUB_ETAG_TIMEOUT", "10")
    # Independent local processing: do not import or invoke the disabled skill.
    # A cached model must already exist; this command performs no model download.
    from faster_whisper import WhisperModel
    model = WhisperModel(args.model, device="cpu", compute_type="int8", local_files_only=True)
    segments, info = model.transcribe(str(args.media), language="zh", vad_filter=True, beam_size=5)
    rows = []
    partial = args.output / "transcript.partial.jsonl"
    with partial.open("w", encoding="utf-8") as log:
        for segment in segments:
            row = {"start": round(segment.start, 2), "end": round(segment.end, 2), "text": segment.text.strip()}
            rows.append(row)
            log.write(json.dumps(row, ensure_ascii=False) + "\n")
            log.flush()
            if len(rows) % 50 == 0:
                print(f"Transcribed through {segment.end:.1f} s", flush=True)
    result = {"backend": "local", "model": args.model, "language": info.language,
              "duration": info.duration, "machine_generated": True, "segments": rows}
    (args.output / "transcript.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.output / "transcript.txt").write_text(
        "\n".join(f"[{r['start']:.2f}-{r['end']:.2f}] {r['text']}" for r in rows), encoding="utf-8")
    partial.unlink()
    print(f"Completed {len(rows)} segments", flush=True)


if __name__ == "__main__":
    main()
