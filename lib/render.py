"""Shared rendering utilities for Jinja2 template processing."""
import yaml
import base64
import re


class IndentDumper(yaml.SafeDumper):
    """Custom YAML dumper with proper indentation."""
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


def represent_multiline_yaml_str():
    """Configure YAML to use literal block style for multiline strings."""
    yaml.SafeDumper.org_represent_str = yaml.SafeDumper.represent_str
    def repr_str(dumper, data):
        if '\n' in data:
            return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
        return dumper.org_represent_str(data)
    yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)

represent_multiline_yaml_str()


def base64encode(s):
    """Encode a string or bytes to base64."""
    if isinstance(s, str):
        s = s.encode("utf-8")
    return base64.b64encode(s).decode("utf-8")


# --- JSONPath upsert helpers -------------------------------------------------

_key_index_re = re.compile(r"([^.\[\]]+)|(\[(\d+)\])")


def _ensure_container(parent, token_key, next_token_is_index):
    """Ensure a container exists at the given key."""
    if isinstance(parent, dict):
        if token_key not in parent or parent[token_key] is None:
            parent[token_key] = [] if next_token_is_index else {}
        return parent[token_key]
    return parent


def set_by_path(doc, path_expr, value):
    """Create-or-update value at a dotted/array path like 'a.b[0].c'."""
    if path_expr.startswith('$'):
        path_expr = path_expr[1:]
    if path_expr.startswith('.'):
        path_expr = path_expr[1:]
    if path_expr == '':
        return value

    tokens = _key_index_re.findall(path_expr)
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
            next_is_index = (i + 1 < len(parsed) and parsed[i+1][0] == 'idx')
            if not isinstance(cur, dict):
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
                    raise TypeError("Root is not a dict; cannot set by key")
            if last:
                cur[tval] = value
                return doc
            parent, parent_key = cur, tval
            cur = _ensure_container(cur, tval, next_is_index)
        else:
            idx = tval
            if not isinstance(cur, list):
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
            while len(cur) <= idx:
                cur.append({})
            if last:
                cur[idx] = value
                return doc
            parent, parent_key = cur, idx
            cur = cur[idx]
    return doc


def resolve_path(data, dotted_path):
    """Check if a dotted path like 'cluster.name' exists in nested dict."""
    parts = dotted_path.split('.')
    cur = data
    for part in parts:
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


def validate_data_for_template(data, meta):
    """Pre-render validation: check platform compatibility and required fields.
    Returns (warnings, errors) tuple of string lists.
    """
    warnings = []
    errors = []
    platform = data.get('cluster', {}).get('platform', 'baremetal') if isinstance(data.get('cluster'), dict) else 'baremetal'
    supported = meta.get('platforms', [])
    if supported and platform not in supported:
        errors.append(
            f"Platform '{platform}' is not supported by template '{meta.get('name', '?')}'."
            f" Supported platforms: {', '.join(supported)}."
            f" Set cluster.platform to one of the above, or use a different template."
        )
    requires = meta.get('requires', [])
    missing = []
    for req in requires:
        if req.startswith('hosts.') or req.startswith('plugins.'):
            continue
        if not resolve_path(data, req):
            missing.append(req)
    if missing:
        warnings.append(
            f"Missing recommended fields: {', '.join(missing)}."
            f" Template may produce incomplete output."
        )
    return warnings, errors


YAMLLINT_CONFIG = 'extends: default\nrules:\n  line-length: disable'
