"""Read-only ZIP inventory and source-token scan; never execute/extract programs.

Encrypted entries are listed as unread. Nested ZIPs are inspected up to four
levels; source content and nested archives above 64 MiB are explicitly skipped.
The resulting JSON records coverage, not proof of algorithm equivalence.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

TEXT_SUFFIXES = {'.m', '.asv', '.py', '.txt', '.md'}
EXACT = ('Bezier_superposition', 'Squares_standard_sum', 'score_cal',
         'Simulation_cal', 'all_routes_cal', 'gradient_power',
         'learning_efficiency', 'perturbation_frequency', 'Scored_index')
OTHER = ('Bezier', '梯度', '平滑', '融合', '叠加', '评分', 'learning', 'gradient')
MAX_BYTES = 64 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def decode(data):
    for encoding in ('utf-8-sig', 'gb18030'):
        try:
            return data.decode(encoding), encoding
        except UnicodeDecodeError:
            pass
    return None, None


def inspect_archive(z, prefix='', depth=0):
    records = []
    for item in z.infolist():
        name = prefix + item.filename
        entry = dict(name=name, bytes=item.file_size,
                     compressedBytes=item.compress_size,
                     encrypted=bool(item.flag_bits & 1))
        records.append(entry)
        if item.is_dir():
            entry['status'] = 'directory'
            continue
        if entry['encrypted']:
            entry['status'] = 'encrypted-not-read'
            continue
        suffix = Path(item.filename).suffix.lower()
        if suffix not in TEXT_SUFFIXES | {'.zip'}:
            entry['status'] = 'binary-listed-not-analyzed'
            continue
        if item.file_size > MAX_BYTES:
            entry['status'] = 'size-limit-not-read'
            continue
        try:
            data = z.read(item)
        except (RuntimeError, zipfile.BadZipFile, NotImplementedError) as exc:
            entry['status'] = 'read-error'
            entry['error'] = str(exc)
            continue
        entry['sha256'] = digest(data)
        if suffix == '.zip':
            if depth >= 4:
                entry['status'] = 'depth-limit-not-inspected'
            else:
                try:
                    with zipfile.ZipFile(io.BytesIO(data)) as nested:
                        entry['status'] = 'nested-archive-inspected'
                        records.extend(inspect_archive(nested, name + '!/', depth + 1))
                except zipfile.BadZipFile:
                    entry['status'] = 'invalid-nested-zip'
            continue
        text, encoding = decode(data)
        if text is None:
            entry['status'] = 'decode-failed'
            continue
        lines = text.replace('\r\r\n', '\n').splitlines()
        entry.update(status='text-scanned', encoding=encoding, lineCount=len(lines))
        entry['exactTokenHits'] = {
            token: [n for n, line in enumerate(lines, 1)
                    if re.search(r'\b' + re.escape(token) + r'\b', line, re.I)]
            for token in EXACT}
        entry['exactTokenHits'] = {k: v for k, v in entry['exactTokenHits'].items() if v}
        entry['relatedTokenHits'] = {
            token: [n for n, line in enumerate(lines, 1) if token.lower() in line.lower()]
            for token in OTHER}
        entry['relatedTokenHits'] = {k: v for k, v in entry['relatedTokenHits'].items() if v}
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--known', type=Path, help='Earlier five-archive evidence JSON')
    args = parser.parse_args()
    known = {}
    if args.known:
        old = json.loads(args.known.read_text(encoding='utf-8'))
        known = {item['sha256']: item['name'] for item in old['archives']}
    archives = []
    for path in sorted(args.source.iterdir()):
        if not path.is_file() or path.suffix.lower() != '.zip':
            continue
        raw = path.read_bytes()
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            entries = inspect_archive(z)
        archive = dict(name=path.name, bytes=len(raw), sha256=digest(raw), entries=entries)
        archive['exactPriorArchive'] = known.get(archive['sha256'])
        archive['coverageCounts'] = dict(Counter(e['status'] for e in entries))
        archives.append(archive)
    entries = [e for a in archives for e in a['entries']]
    report = dict(sourceDirectory=str(args.source.resolve()), archiveCount=len(archives),
                  exactPriorArchiveCount=sum(a['exactPriorArchive'] is not None for a in archives),
                  coverageCounts=dict(Counter(e['status'] for e in entries)),
                  exactTokens=list(EXACT), relatedTokens=list(OTHER), archives=archives,
                  scope='Inventory and decoded-text token scan only. Absence of names does not prove absence of equivalent logic; encrypted and binary contents remain unreviewed.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('archiveCount', 'exactPriorArchiveCount', 'coverageCounts')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
