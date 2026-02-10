#!/usr/bin/env python3
import yaml
from jinja2 import Environment, FileSystemLoader, TemplateNotFound
import argparse
import os
import sys
import base64
import yamllint.config
import yamllint.linter
import jsonpath_ng
import json
import re
try:
    import jsonschema
    from jsonschema import FormatChecker
except Exception:
    jsonschema = None

class IndentDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

def __represent_multiline_yaml_str():
    """Compel ``yaml`` library to use block style literals for multi-line
    strings to prevent unwanted multiple newlines.
    """
    yaml.SafeDumper.org_represent_str = yaml.SafeDumper.represent_str
    def repr_str(dumper, data):
        if '\n' in data:
            return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
        return dumper.org_represent_str(data)
    yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)
__represent_multiline_yaml_str()

def load_file(path):
    if not path or not isinstance(path, str):
        return ""
    try:
        with open(path, 'r') as f:
            content = f.read()
        return content.rstrip()
    except (FileNotFoundError, IOError):
        return ""

def base64encode(s):
    if isinstance(s, str):
        s = s.encode("utf-8")
    return base64.b64encode(s).decode("utf-8")

def process_template(config_data, template_file, data_file):
    """
    Processes a Jinja2 template with data loaded from a YAML file.

    Args:
        config_data: yaml object
        template_file (str): Path to the main Jinja2 template file.
    """
    template_dir = os.path.dirname(os.path.abspath(template_file))
    config_dir   = os.path.dirname(os.path.abspath(data_file))
    includes_dir = os.path.join(template_dir, 'includes')
    env = Environment(loader=FileSystemLoader([template_dir, includes_dir, config_dir]))
    env.globals["load_file"] = load_file
    env.filters["base64encode"] = base64encode
    try:
        template = env.get_template(os.path.basename(template_file))
    except jinja2.exceptions.TemplateNotFound:
        raise FileNotFoundError(f"Error: Template file '{template_file}' not found.")
    return template.render(config_data)

# --- JSONPath upsert helpers -------------------------------------------------

_key_index_re = re.compile(r"([^.\[\]]+)|(\[(\d+)\])")  # tokens: key or [index]

def _ensure_container(parent, token_key, next_token_is_index):
    """Ensure that the next container exists under parent for token_key.
    If next is index -> create list; else create dict.
    """
    if isinstance(parent, dict):
        if token_key not in parent or parent[token_key] is None:
            parent[token_key] = [] if next_token_is_index else {}
        return parent[token_key]
    return parent  # best effort; caller guards types

def _set_by_path(doc, path_expr, value):
    """Create-or-update value at a dotted/array path like:
       'a.b[0].c' or '$.a.b[1]'. Creates missing dicts/lists as needed.
    """
    # Normalize: remove leading '$' and optional '.'
    if path_expr.startswith('$'):
        path_expr = path_expr[1:]
    if path_expr.startswith('.'):
        path_expr = path_expr[1:]

    if path_expr == '':
        # root replacement (rare; not recommended)
        return value

    tokens = _key_index_re.findall(path_expr)
    # tokens is list of tuples (key, idx_group, idx_num). We map to sequence of ('key', name) or ('idx', int)
    parsed = []
    for key, idxgrp, idxnum in tokens:
        if key:
            parsed.append(('key', key))
        else:
            parsed.append(('idx', int(idxnum)))

    cur = doc
    parent = None
    parent_key = None
    for i, (ttype, tval) in enumerate(parsed):
        last = (i == len(parsed) - 1)
        if ttype == 'key':
            # lookahead: is next token an index?
            next_is_index = (i + 1 < len(parsed) and parsed[i+1][0] == 'idx')
            if not isinstance(cur, dict):
                # convert to dict if possible
                if parent is not None:
                    if isinstance(parent, list) and isinstance(parent_key, int):
                        parent[parent_key] = {}
                        cur = parent[parent_key]
                    elif isinstance(parent, dict):
                        parent[parent_key] = {}
                        cur = parent[parent_key]
                    else:
                        raise TypeError("Path traversal encountered non-container type")
                else:
                    raise TypeError("Root is not a dict; cannot set by key")  # shouldn't happen for our usage
            if last:
                cur[tval] = value
                return doc
            parent, parent_key = cur, tval
            cur = _ensure_container(cur, tval, next_is_index)
        else:  # index
            idx = tval
            if not isinstance(cur, list):
                # convert to list
                if parent is not None:
                    if isinstance(parent, dict):
                        parent[parent_key] = []
                        cur = parent[parent_key]
                    elif isinstance(parent, list) and isinstance(parent_key, int):
                        parent[parent_key] = []
                        cur = parent[parent_key]
                    else:
                        raise TypeError("Path traversal encountered non-container type")
                else:
                    raise TypeError("Root is not a list; cannot index")
            # ensure size
            while len(cur) <= idx:
                cur.append({})
            if last:
                cur[idx] = value
                return doc
            parent, parent_key = cur, idx
            cur = cur[idx]
    return doc

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process Jinja2 templates with YAML data.")
    parser.add_argument("data_file", nargs="?", help="Path to the YAML data file, inline JSON string, or omit to use -p only")
    parser.add_argument("template_file", help="Path to the main Jinja2 template file")
    parser.add_argument(
        "-p", "--param", action="append", default=[],
        help="Override parameter using JSONPath syntax: path=value (repeatable). Supports dotted paths and [index]."
    )
    parser.add_argument("-s", "--schema", help="Path to a JSON Schema (JSON or YAML) to validate the data file against")
    parser.add_argument("--validate-scope", choices=["data", "data+params"], default="data",
                        help="When to run schema validation: 'data' validates before overrides, 'data+params' validates again after applying -p overrides")
    parser.add_argument("-S", dest="validate_data_and_params", action="store_true",
                        help="Shortcut flag: if present, validate both data and params (equivalent to --validate-scope=data+params)")
    args = parser.parse_args()

    # If the -S shortcut flag was used, set validate_scope accordingly
    if getattr(args, 'validate_data_and_params', False):
        args.validate_scope = "data+params"

    # Load data source (file path OR inline JSON). If omitted, start from {}.
    data = {}
    if args.data_file:
        # Try parsing as JSON string first
        try:
            data = json.loads(args.data_file)
        except Exception:
            # Fallback to file path (YAML/JSON)
            try:
                with open(args.data_file, 'r') as f:
                    data = yaml.safe_load(f) or {}
            except FileNotFoundError:
                raise FileNotFoundError(f"Error: Data file '{args.data_file}' not found.")
            except yaml.YAMLError as e:
                raise ValueError(f"Error: Invalid YAML format in '{args.data_file}': {e}")

    # Schema validation helpers
    def _load_schema(path):
        s = None
        try:
            with open(path, 'r') as fh:
                txt = fh.read()
        except Exception as e:
            raise FileNotFoundError(f"Schema file '{path}' not found: {e}")
        try:
            s = json.loads(txt)
        except Exception:
            try:
                s = yaml.safe_load(txt)
            except Exception as e:
                raise ValueError(f"Could not parse schema file '{path}': {e}")
        return s

    def _validate_against_schema(obj, schema_path):
        if not args.schema:
            return []
        if jsonschema is None:
            raise RuntimeError("jsonschema package is required for schema validation. Install with: pip install jsonschema")
        schema = _load_schema(schema_path)
        Validator = jsonschema.validators.validator_for(schema)
        validator = Validator(schema, format_checker=FormatChecker())
        errors = sorted(validator.iter_errors(obj), key=lambda e: list(e.path))
        msgs = []
        for e in errors:
            p = ".".join([str(x) for x in e.path]) if e.path else "<root>"
            msgs.append(f"{p}: {e.message}")
        return msgs

    # If a schema was provided and scope includes 'data', validate original data before applying overrides
    if args.schema and args.validate_scope in ("data", "data+params"):
        try:
            errs = _validate_against_schema(data, args.schema)
        except Exception as e:
            print(f"Schema validation setup error: {e}", file=sys.stderr)
            sys.exit(2)
        if errs:
            print("Schema validation errors (data file):", file=sys.stderr)
            for m in errs:
                print(m, file=sys.stderr)
            sys.exit(2)

    # Require at least one input source
    if not args.data_file and not args.param:
        parser.error("Provide either a data_file or at least one -p override.")

    # Apply JSONPath overrides with create-if-missing semantics
    for override in args.param:
        if "=" not in override:
            continue
        path_expr, val = override.split("=", 1)
        # allow multi-line via \n, \t, etc.
        val = val.encode("utf-8").decode("unicode_escape")
        try:
            # Try strict JSONPath update for existing nodes
            expr = jsonpath_ng.parse(path_expr)
            matches = expr.find(data)
            if matches:
                for m in matches:
                    m.full_path.update(data, val)
                continue
        except Exception:
            # If parse fails, fall back to dotted/indexed path
            pass
        # Create missing structure using dotted/index fallback
        _set_by_path(data, path_expr, val)

    # If schema provided and scope is data+params, validate now after applying overrides
    if args.schema and args.validate_scope == "data+params":
        try:
            errs = _validate_against_schema(data, args.schema)
        except Exception as e:
            print(f"Schema validation setup error: {e}", file=sys.stderr)
            sys.exit(2)
        if errs:
            print("Schema validation errors (after applying overrides):", file=sys.stderr)
            for m in errs:
                print(m, file=sys.stderr)
            sys.exit(2)

    config = yamllint.config.YamlLintConfig('extends: default\nrules:\n  line-length: disable')

    try:
        processedTemplate = process_template(data, args.template_file, args.data_file)
    except (FileNotFoundError, ValueError) as e:
        print(e)

    if args.template_file.endswith('yaml.tpl') or args.template_file.endswith('yaml.tmpl'):
        outputDict = {}
        try:
            outputDict = yaml.safe_load(processedTemplate)
        except Exception as e:
            print(e)

        outputYaml = yaml.dump(
            outputDict,
            width=4096,
            Dumper=IndentDumper,
            explicit_start=True,
            indent=2,
            sort_keys=False,
            default_style=None,
            default_flow_style=None,
            allow_unicode=True
        )

        try:
            problems = yamllint.linter.run(outputYaml, config)
            for problem in problems:
                print(problem, file=sys.stderr)
            print(outputYaml)
        except Exception as e:
            print(e)
    else:
        print(processedTemplate)
