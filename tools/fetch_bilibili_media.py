"""Resume public media from the installed reader's local metadata.

Small HTTP ranges avoid losing an entire download to a slow connection.
The metadata and downloaded media belong in the Git-ignored local/ directory.
This does not obtain cookies, change TLS verification, or unlock paid media.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

from curl_cffi import requests


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("metadata", type=Path)
    parser.add_argument("format_id")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
    fmt = next(f for f in metadata["formats"] if str(f["format_id"]) == args.format_id)
    target = args.output.resolve()
    if target.exists():
        parser.error("Output already exists; choose a different name or inspect the existing file.")
    target.parent.mkdir(parents=True, exist_ok=True)
    part = target.with_suffix(target.suffix + ".part")
    position = part.stat().st_size if part.exists() else 0
    # Only resume a partial file produced from this exact format and source.
    source = {"video_id": metadata["id"], "format_id": args.format_id}
    sidecar = part.with_suffix(part.suffix + ".json")
    if position:
        if not sidecar.exists() or json.loads(sidecar.read_text()) != source:
            parser.error("Partial file lacks a matching source manifest; do not append blindly.")
    else:
        sidecar.write_text(json.dumps(source), encoding="utf-8")
    with requests.Session(impersonate="chrome") as session, part.open("ab") as stream:
        while True:
            end = position + 2 * 1024 * 1024 - 1
            response = session.get(fmt["url"], headers={
                "Referer": metadata["webpage_url"], "Range": f"bytes={position}-{end}",
            }, timeout=(10, 40))
            response.raise_for_status()
            match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
            if response.status_code != 206 or not match:
                raise RuntimeError("Server did not honor the bounded range request.")
            first, last, total = map(int, match.groups())
            if first != position or last > end or len(response.content) != last - first + 1:
                raise RuntimeError("Unexpected media range; partial file was not changed.")
            stream.write(response.content)
            stream.flush()
            position = last + 1
            print(f"{target.name}: {position}/{total} bytes", flush=True)
            if position == total:
                break
    part.rename(target)
    with target.open("rb") as media:
        digest = hashlib.file_digest(media, "sha256").hexdigest()
    manifest = {**source, "title": metadata["title"], "source_url": metadata["webpage_url"],
                "bytes": target.stat().st_size, "sha256": digest}
    target.with_suffix(target.suffix + ".source.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sidecar.unlink()


if __name__ == "__main__":
    main()
