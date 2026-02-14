"""Template processor for Jinja2 rendering with YAML output."""
import yaml
from jinja2 import Environment, FileSystemLoader, UndefinedError
import os
import base64
import yamllint.config
import yamllint.linter
import jsonpath_ng
import re
from pathlib import Path


class IndentDumper(yaml.SafeDumper):
    """Custom YAML dumper with proper indentation."""
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


def _represent_multiline_yaml_str():
    """Configure YAML to use literal block style for multiline strings."""
    yaml.SafeDumper.org_represent_str = yaml.SafeDumper.represent_str
    def repr_str(dumper, data):
        if '\n' in data:
            return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
        return dumper.org_represent_str(data)
    yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)

_represent_multiline_yaml_str()


def load_file(path: str) -> str:
    """
    Return a placeholder for file paths.
    In browser context, we don't read actual file contents.
    Templates will show <file:path> placeholders for x-is-file fields.
    """
    if not path or not isinstance(path, str):
        return ""
    return f"<file:{path}>"


def base64encode(s) -> str:
    """Encode a string or bytes to base64."""
    if isinstance(s, str):
        s = s.encode("utf-8")
    return base64.b64encode(s).decode("utf-8")


_key_index_re = re.compile(r"([^.\[\]]+)|(\[(\d+)\])")


def _ensure_container(parent, token_key, next_token_is_index):
    """Ensure a container exists at the given key."""
    if isinstance(parent, dict):
        if token_key not in parent or parent[token_key] is None:
            parent[token_key] = [] if next_token_is_index else {}
        return parent[token_key]
    return parent


def _set_by_path(doc: dict, path_expr: str, value) -> dict:
    """Set a value in a nested dict/list structure using a JSONPath-like expression."""
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


def apply_params(data: dict, params: list) -> dict:
    """Apply JSONPath parameter overrides to data."""
    for override in params:
        if "=" not in override:
            continue
        path_expr, val = override.split("=", 1)
        val = val.encode("utf-8").decode("unicode_escape")
        try:
            expr = jsonpath_ng.parse(path_expr)
            matches = expr.find(data)
            if matches:
                for m in matches:
                    m.full_path.update(data, val)
                continue
        except Exception:
            pass
        _set_by_path(data, path_expr, val)
    return data


def process_template(config_data: dict, template_content: str, template_dir: str) -> str:
    """Process a Jinja2 template with the given configuration data."""
    includes_dir = os.path.join(template_dir, 'includes')
    plugins_tpl  = os.path.join(template_dir, 'plugins')
    plugins_root = os.path.join(os.path.dirname(template_dir), 'plugins')
    loader_paths = [template_dir]
    if os.path.exists(includes_dir):
        loader_paths.append(includes_dir)
    if os.path.exists(plugins_tpl):
        loader_paths.append(plugins_tpl)
    if os.path.exists(plugins_root):
        loader_paths.append(plugins_root)

    env = Environment(loader=FileSystemLoader(loader_paths))
    env.globals["load_file"] = load_file
    env.filters["base64encode"] = base64encode

    template = env.from_string(template_content)
    return template.render(config_data)


def _resolve_path(data, dotted_path):
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
        if not _resolve_path(data, req):
            missing.append(req)
    if missing:
        warnings.append(
            f"Missing recommended fields: {', '.join(missing)}."
            f" Template may produce incomplete output."
        )
    return warnings, errors


def render_template(yaml_text: str, template_name: str, params: list, templates_dir: Path) -> dict:
    """Render a Jinja2 template with YAML data and optional parameter overrides."""
    # Parse YAML input
    try:
        data = yaml.safe_load(yaml_text) or {}
    except yaml.YAMLError as e:
        return {"success": False, "error": f"Invalid YAML: {e}", "output": ""}

    # Apply parameter overrides
    if params:
        try:
            data = apply_params(data, params)
        except Exception as e:
            return {"success": False, "error": f"Failed to apply parameters: {e}", "output": ""}

    # Validate template path
    template_path = templates_dir / template_name
    if not template_path.exists():
        return {"success": False, "error": f"Template not found: {template_name}", "output": ""}

    # Security: prevent path traversal
    safe_name = os.path.basename(template_name)
    if safe_name != template_name or ".." in template_name:
        return {"success": False, "error": "Invalid template name", "output": ""}

    # Read template
    try:
        with open(template_path, 'r') as f:
            template_content = f.read()
    except Exception as e:
        return {"success": False, "error": f"Failed to read template: {e}", "output": ""}

    # Pre-render validation
    meta = parse_template_metadata(template_content)
    val_warnings, val_errors = validate_data_for_template(data, meta)
    if val_errors:
        return {"success": False, "error": val_errors[0], "output": "", "warnings": val_warnings}

    # Render template
    try:
        processed = process_template(data, template_content, str(templates_dir))
    except UndefinedError as e:
        msg = str(e)
        tpl_name = meta.get('name', template_name)
        requires = meta.get('requires', [])
        hint = f" Required fields: {', '.join(requires)}" if requires else ""
        return {"success": False, "error": f"Error rendering '{tpl_name}': {msg}.{hint}", "output": "", "warnings": val_warnings}
    except Exception as e:
        return {"success": False, "error": f"Template rendering failed: {e}", "output": "", "warnings": val_warnings}

    # Format YAML output if applicable
    if template_name.endswith('.yaml.tpl') or template_name.endswith('.yaml.tmpl'):
        try:
            docs = [d for d in yaml.safe_load_all(processed) if d is not None]
            output_obj = docs[0] if len(docs) == 1 else docs
            output_yaml = yaml.dump(
                output_obj,
                width=4096,
                Dumper=IndentDumper,
                explicit_start=True,
                indent=2,
                sort_keys=False,
                default_style=None,
                default_flow_style=None,
                allow_unicode=True
            )

            # Run yamllint
            config = yamllint.config.YamlLintConfig('extends: default\nrules:\n  line-length: disable')
            problems = list(yamllint.linter.run(output_yaml, config))
            warnings = val_warnings + [str(p) for p in problems]

            return {
                "success": True,
                "output": output_yaml,
                "warnings": warnings,
                "error": ""
            }
        except Exception as e:
            return {"success": False, "error": f"YAML processing failed: {e}", "output": processed, "warnings": val_warnings}

    return {"success": True, "output": processed, "warnings": val_warnings, "error": ""}


def parse_template_metadata(content: str) -> dict:
    """
    Parse @meta block from template content.

    Metadata format:
    {#- @meta
    name: template-name.yaml
    description: What this template does
    type: clusterfile|other
    category: installation|credentials|acm|configuration|utility|storage
    platforms: [list of supported platforms]
    requires: [list of required data fields]
    docs: URL to documentation
    -#}
    """
    meta = {
        "name": "",
        "description": "",
        "type": "other",
        "category": "other",
        "platforms": [],
        "requires": [],
        "docs": ""
    }

    # Look for @meta block
    import re
    match = re.search(r'\{#-?\s*@meta\s*\n(.*?)\n\s*-?#\}', content, re.DOTALL)
    if not match:
        return meta

    meta_text = match.group(1)
    try:
        parsed = yaml.safe_load(meta_text)
        if isinstance(parsed, dict):
            meta.update(parsed)
    except Exception:
        pass

    return meta


def list_templates(templates_dir: Path) -> list:
    """List all available templates with metadata."""
    templates = []
    if not templates_dir.exists():
        return templates

    for f in sorted(templates_dir.glob("*.tpl")):
        try:
            content = f.read_text()
            meta = parse_template_metadata(content)
            meta["filename"] = f.name
            if not meta["name"]:
                meta["name"] = f.name
            if not meta["description"]:
                meta["description"] = get_template_description(f)
            templates.append(meta)
        except Exception:
            templates.append({
                "filename": f.name,
                "name": f.name,
                "description": get_template_description(f),
                "type": "other",
                "category": "other",
                "platforms": [],
                "requires": [],
                "docs": ""
            })

    for f in sorted(templates_dir.glob("*.tmpl")):
        try:
            content = f.read_text()
            meta = parse_template_metadata(content)
            meta["filename"] = f.name
            if not meta["name"]:
                meta["name"] = f.name
            if not meta["description"]:
                meta["description"] = get_template_description(f)
            templates.append(meta)
        except Exception:
            templates.append({
                "filename": f.name,
                "name": f.name,
                "description": get_template_description(f),
                "type": "other",
                "category": "other",
                "platforms": [],
                "requires": [],
                "docs": ""
            })

    return templates


def get_template_description(template_path: Path) -> str:
    """Get a fallback description for a template without metadata."""
    descriptions = {
        "install-config.yaml.tpl": "OpenShift install-config.yaml (unified for all platforms)",
        "creds.yaml.tpl": "CCO credentials for cloud platforms (AWS, Azure, GCP, etc.)",
        "agent-config.yaml.tpl": "Agent-based installer agent-config.yaml with bond/VLAN",
        "acm-ztp.yaml.tpl": "ACM Zero Touch Provisioning configuration",
        "acm-capi-m3.yaml.tpl": "ACM CAPI + Metal3 configuration for MCE",
        "acm-creds.yaml.tpl": "ACM host inventory credentials",
        "acm-asc.yaml.tpl": "ACM Assisted Service ConfigMap",
        "mirror-registry-config.yaml.tpl": "Mirror registry configuration",
        "nodes-config.yaml.tpl": "Node network configuration with NMState",
        "secondary-network-setup.yaml.tpl": "Secondary network NNCP configuration",
        "infinidat-setup.yaml.tpl": "Infinidat storage configuration",
        "test-dns.sh.tpl": "DNS verification script",
    }
    return descriptions.get(template_path.name, "Jinja2 template")


def get_template_content(template_name: str, templates_dir: Path) -> dict:
    """Get the raw content of a template file."""
    safe_name = os.path.basename(template_name)
    if safe_name != template_name or ".." in template_name:
        return {"success": False, "error": "Invalid template name", "content": ""}

    template_path = templates_dir / template_name
    if not template_path.exists():
        return {"success": False, "error": f"Template not found: {template_name}", "content": ""}

    try:
        with open(template_path, 'r') as f:
            return {"success": True, "content": f.read(), "error": ""}
    except Exception as e:
        return {"success": False, "error": f"Failed to read template: {e}", "content": ""}
