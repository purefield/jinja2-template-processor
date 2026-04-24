#!/usr/bin/env python3
"""Extract every x-doc-url from clusterfile schemas into a CSV for hand-update.

Output columns:
    source_file       - relative path to the schema file containing the URL
    json_path         - dotted path to the property (e.g., cluster.platform)
    title             - schema 'title' field for the property
    description       - schema 'description' field (truncated to 200 chars)
    current_url       - the existing x-doc-url value
    new_url           - empty; user fills this in for re-import

Usage:
    python3 scripts/extract-doc-urls.py > schema/x-doc-urls.csv
"""
import csv
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_FILES = [
    REPO_ROOT / "schema/clusterfile.schema.json",
] + sorted(REPO_ROOT.glob("plugins/**/schema.json"))


def walk(node, path, source_file, rows):
    """Recursively walk a JSON Schema, emitting a row for every x-doc-url."""
    if isinstance(node, dict):
        if "x-doc-url" in node:
            url = node["x-doc-url"]
            urls = url if isinstance(url, list) else [url]
            for u in urls:
                rows.append({
                    "source_file": str(source_file.relative_to(REPO_ROOT)),
                    "json_path": ".".join(path) if path else "(root)",
                    "title": node.get("title", ""),
                    "description": (node.get("description", "") or "")[:200],
                    "current_url": u,
                    "new_url": "",
                })
        for key, value in node.items():
            if key in ("properties", "patternProperties"):
                if isinstance(value, dict):
                    for prop_name, prop_node in value.items():
                        walk(prop_node, path + [prop_name], source_file, rows)
            elif key in ("items", "additionalProperties", "if", "then", "else", "not"):
                walk(value, path + [f"<{key}>"], source_file, rows)
            elif key in ("oneOf", "anyOf", "allOf"):
                if isinstance(value, list):
                    for i, sub in enumerate(value):
                        walk(sub, path + [f"<{key}[{i}]>"], source_file, rows)
            elif key == "$defs" or key == "definitions":
                if isinstance(value, dict):
                    for def_name, def_node in value.items():
                        walk(def_node, [f"<$defs.{def_name}>"], source_file, rows)


def main():
    rows = []
    for schema_path in SCHEMA_FILES:
        with open(schema_path) as f:
            schema = json.load(f)
        walk(schema, [], schema_path, rows)

    rows.sort(key=lambda r: (r["source_file"], r["json_path"]))

    writer = csv.DictWriter(
        sys.stdout,
        fieldnames=["source_file", "json_path", "title", "description", "current_url", "new_url"],
    )
    writer.writeheader()
    writer.writerows(rows)


if __name__ == "__main__":
    main()
