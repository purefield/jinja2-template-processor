#!/usr/bin/env python3
import yaml
from jinja2 import Environment, FileSystemLoader
import argparse
import os
import sys
import yamllint.config
import yamllint.linter

class IndentDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

def load_file(path):
    if not path or not isinstance(path, str):
        return ""
    try:
        with open(path, 'r') as f:
            content = f.read()
        return content
    except (FileNotFoundError, IOError):
        return ""

def process_template(data_file, template_file):
    """
    Processes a Jinja2 template with data loaded from a YAML file.

    Args:
        data_file (str): Path to the YAML data file.
        template_file (str): Path to the main Jinja2 template file.
    """
    try:
        with open(data_file, 'r') as f:
            data = yaml.safe_load(f)
    except FileNotFoundError:
         raise FileNotFoundError(f"Error: Data file '{data_file}' not found.")
    except yaml.YAMLError as e:
        raise ValueError(f"Error: Invalid YAML format in '{data_file}': {e}")
    template_dir = os.path.dirname(os.path.abspath(template_file))
    env = Environment(loader=FileSystemLoader(template_dir))
    env.globals["load_file"] = load_file
    try:
        template = env.get_template(os.path.basename(template_file))
    except jinja2.exceptions.TemplateNotFound:
        raise FileNotFoundError(f"Error: Template file '{template_file}' not found.")
    rendered_output = template.render(data)
    return rendered_output

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process Jinja2 templates with YAML data.")
    parser.add_argument("data_file",     help="Path to the YAML data file")
    parser.add_argument("template_file", help="Path to the main Jinja2 template file")
    args = parser.parse_args()
    config = yamllint.config.YamlLintConfig('extends: default\nrules:\n  line-length: disable')

    try:
        processedTemplate = process_template(args.data_file, args.template_file)
        # print(processedTemplate)
    except (FileNotFoundError, ValueError) as e:
        print(e)

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

