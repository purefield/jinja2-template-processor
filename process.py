#!/usr/bin/env python3
import yaml
from jinja2 import Environment, FileSystemLoader, TemplateNotFound, UndefinedError
import argparse
import os
import sys
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

from lib.render import (
    IndentDumper, base64encode, set_by_path,
    resolve_path, validate_data_for_template, YAMLLINT_CONFIG,
)

def load_file(path):
    if not path or not isinstance(path, str):
        return ""
    try:
        with open(path, 'r') as f:
            content = f.read()
        return content.rstrip()
    except (FileNotFoundError, IOError):
        print(f"WARNING: load_file('{path}'): file not found or unreadable", file=sys.stderr)
        return ""

def parse_template_meta(template_file):
    """Parse @meta block from a template file."""
    meta = {"name": "", "platforms": [], "requires": []}
    try:
        with open(template_file, 'r') as f:
            content = f.read()
        match = re.search(r'\{#-?\s*@meta\s*\n(.*?)\n\s*-?#\}', content, re.DOTALL)
        if match:
            parsed = yaml.safe_load(match.group(1))
            if isinstance(parsed, dict):
                meta.update(parsed)
    except Exception:
        pass
    return meta

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
    plugins_tpl  = os.path.join(template_dir, 'plugins')
    repo_root    = os.path.dirname(template_dir)
    plugins_root = os.path.join(repo_root, 'plugins')
    env = Environment(loader=FileSystemLoader([template_dir, includes_dir, plugins_tpl, plugins_root, config_dir]))
    env.globals["load_file"] = load_file
    env.filters["base64encode"] = base64encode
    try:
        template = env.get_template(os.path.basename(template_file))
    except TemplateNotFound:
        raise FileNotFoundError(f"Error: Template file '{template_file}' not found.")
    return template.render(config_data)

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
        # Auto-discover operator plugin schemas
        schema_dir = os.path.dirname(os.path.abspath(path))
        plugins_operators = os.path.join(os.path.dirname(schema_dir), 'plugins', 'operators')
        if os.path.isdir(plugins_operators):
            s.setdefault('$defs', {})
            ops = (s.setdefault('properties', {}).setdefault('plugins', {})
                    .setdefault('properties', {}).setdefault('operators', {})
                    .setdefault('properties', {}))
            for dirname in sorted(os.listdir(plugins_operators)):
                sf = os.path.join(plugins_operators, dirname, 'schema.json')
                if os.path.isfile(sf):
                    def_key = 'operator' + ''.join(p.capitalize() for p in dirname.split('-'))
                    with open(sf) as fh:
                        s['$defs'][def_key] = json.load(fh)
                    ops[dirname] = {"$ref": f"#/$defs/{def_key}"}
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
        set_by_path(data, path_expr, val)

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

    config = yamllint.config.YamlLintConfig(YAMLLINT_CONFIG)

    # Pre-render validation: check platform and required fields
    meta = parse_template_meta(args.template_file)
    val_warnings, val_errors = validate_data_for_template(data, meta)
    for w in val_warnings:
        print(w, file=sys.stderr)
    if val_errors:
        for e in val_errors:
            print(e, file=sys.stderr)
        sys.exit(1)

    try:
        processedTemplate = process_template(data, args.template_file, args.data_file)
    except UndefinedError as e:
        msg = str(e)
        tpl_name = meta.get('name', os.path.basename(args.template_file))
        print(f"Error rendering '{tpl_name}': {msg}", file=sys.stderr)
        requires = meta.get('requires', [])
        if requires:
            print(f"This template requires: {', '.join(requires)}", file=sys.stderr)
        sys.exit(1)
    except (FileNotFoundError, ValueError) as e:
        print(e, file=sys.stderr)
        sys.exit(1)

    if args.template_file.endswith('yaml.tpl') or args.template_file.endswith('yaml.tmpl'):
        try:
            docs = [d for d in yaml.safe_load_all(processedTemplate) if d is not None]
        except Exception as e:
            print(e)
            sys.exit(1)

        outputObj = docs[0] if len(docs) == 1 else {"apiVersion": "v1", "kind": "List", "items": docs}
        outputYaml = yaml.dump(
            outputObj,
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
