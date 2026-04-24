#!/usr/bin/env python3
"""Import updated x-doc-url values from CSV back into schema files.

Reads schema/x-doc-urls.csv. For every row where new_url is non-empty
and differs from current_url, replaces that exact current_url string in
the matching source_file. Replacement is done as a literal string swap;
URLs are unique enough (and the CSV pairs them with source_file) that
ambiguity is rare. If the same current_url appears multiple times in a
file with different intended replacements, the importer will apply the
new_url from the first matching row to all occurrences in that file —
hand-edit those after the import if the CSV had distinct intent.

Usage:
    python3 scripts/import-doc-urls.py [--dry-run]

Default behavior writes changes in place. --dry-run prints what would
change without modifying files.
"""
import argparse
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_csv(csv_path):
    with open(csv_path, newline="") as f:
        return list(csv.DictReader(f))


def group_by_file(rows):
    """Return {source_file: [(current_url, new_url), ...]} keeping uniqueness."""
    by_file = defaultdict(list)
    seen = defaultdict(set)
    for r in rows:
        new = (r.get("new_url") or "").strip()
        cur = (r.get("current_url") or "").strip()
        src = r["source_file"]
        if not new or new == cur:
            continue
        key = (cur, new)
        if key in seen[src]:
            continue
        seen[src].add(key)
        by_file[src].append(key)
    return by_file


def apply(by_file, dry_run):
    total_files = 0
    total_swaps = 0
    for src, swaps in sorted(by_file.items()):
        path = REPO_ROOT / src
        text = path.read_text()
        original = text
        for cur, new in swaps:
            count = text.count(cur)
            if count == 0:
                print(f"WARN  {src}: current_url not found, skipping: {cur}", file=sys.stderr)
                continue
            text = text.replace(cur, new)
            total_swaps += count
            print(f"OK    {src}: {count}x  {cur}\n           ->  {new}")
        if text != original:
            total_files += 1
            try:
                json.loads(text)
            except json.JSONDecodeError as e:
                print(f"ERROR {src}: edit produced invalid JSON ({e}), skipping write", file=sys.stderr)
                continue
            if not dry_run:
                path.write_text(text)
    mode = "would update" if dry_run else "updated"
    print(f"\n{mode} {total_files} file(s), {total_swaps} URL replacement(s)")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="Show changes without writing")
    ap.add_argument("--csv", default="schema/x-doc-urls.csv", help="Path to CSV (default: schema/x-doc-urls.csv)")
    args = ap.parse_args()

    rows = load_csv(REPO_ROOT / args.csv)
    by_file = group_by_file(rows)
    if not by_file:
        print("Nothing to do — no rows have a new_url that differs from current_url.")
        return
    apply(by_file, args.dry_run)


if __name__ == "__main__":
    main()
