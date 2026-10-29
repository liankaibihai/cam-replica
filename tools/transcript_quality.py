"""Flag obvious ASR failures; passing does not certify accurate captions."""
from itertools import groupby
import re


def inspect_transcript(rows, duration):
    repeats = []
    for text, group in groupby(rows, key=lambda row: re.sub(r"\s+", "", row["text"])):
        items = list(group)
        if len(items) >= 12:
            repeats.append({"text": text, "count": len(items),
                            "start": items[0]["start"], "end": items[-1]["end"]})
    overrun = max(0, max((r["end"] for r in rows), default=0) - duration)
    return {"passed": bool(rows) and not repeats and overrun <= 1,
            "repeat_runs": repeats, "timestamp_overrun_seconds": round(overrun, 3),
            "scope": "Obvious repetition and timestamp failures only; not caption accuracy certification."}
