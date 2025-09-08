#!/usr/bin/env python3
import yaml
from jinja2 import Environment, FileSystemLoader
import argparse
import os
import sys
import base64
import yamllint.config
import yamllint.linter
import jsonpath_ng

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
            return dumper.represent_scalar(
                'tag:yaml.org,2002:str', data, style='|')
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

def process_template(config_data, template_file):
    """
    Processes a Jinja2 template with data loaded from a YAML file.

    Args:
        config_data: yaml object
        template_file (str): Path to the main Jinja2 template file.
    """
    template_dir = os.path.dirname(os.path.abspath(template_file))
    includes_dir = os.path.join(template_dir, 'includes')
    env = Environment(loader=FileSystemLoader([template_dir,includes_dir]))
    env.globals["load_file"] = load_file
    env.filters["base64encode"] = base64encode
    try:
        template = env.get_template(os.path.basename(template_file))
    except jinja2.exceptions.TemplateNotFound:
        raise FileNotFoundError(f"Error: Template file '{template_file}' not found.")
    rendered_output = template.render(config_data)
    return rendered_output

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process Jinja2 templates with YAML data.")
    parser.add_argument("data_file",     help="Path to the YAML data file")
    parser.add_argument("template_file", help="Path to the main Jinja2 template file")
    parser.add_argument(
        "-p", "--param", action="append", default=[],
        help="Override parameter using JSONPath syntax: path=value (repeatable)"
    )
    args = parser.parse_args()

    try:
        with open(args.data_file, 'r') as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"Error: Data file '{args.data_file}' not found.")
    except yaml.YAMLError as e:
        raise ValueError(f"Error: Invalid YAML format in '{args.data_file}': {e}")

    # Apply JSONPath overrides
    for override in args.param:
        if "=" not in override:
            continue
        path_expr, val = override.split("=", 1)
        expr = jsonpath_ng.parse(path_expr)
        val = val.encode("utf-8").decode("unicode_escape")
        for match in expr.find(data):
            path = match.full_path
            path.update(data, val)

    import tempfile
    tmp = tempfile.NamedTemporaryFile("w+", delete=False)
    yaml.safe_dump(data, tmp)
    tmp.flush()
    data_file = tmp.name

    config = yamllint.config.YamlLintConfig('extends: default\nrules:\n  line-length: disable')

    try:
        processedTemplate = process_template(data, args.template_file)
        # print(processedTemplate)
    except (FileNotFoundError, ValueError) as e:
        print(e)

    if args.template_file.endswith('yaml.tpl'):
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
            # print(processedTemplate)
        except Exception as e:
            print(e)
    else:
        print(processedTemplate)
