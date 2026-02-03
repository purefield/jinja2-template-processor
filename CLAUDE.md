# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Jinja2 template processor for generating OpenShift/Kubernetes configuration files from YAML clusterfiles. The project has two main components:

1. **CLI tool** (`process.py`) - Renders Jinja2 templates using YAML data with JSONPath overrides and schema validation
2. **Web editor** (`apps/editor/`) - FastAPI-based web UI for editing clusterfiles with live template rendering

## Common Commands

### CLI Template Processing
```bash
# Install dependencies
pip install -r requirements.txt

# Basic template rendering
./process.py data/customer.example.bond.vlan.clusterfile templates/agent-config-bond-vlan.yaml.tpl

# With JSONPath overrides
./process.py data/customer.example.clusterfile templates/install-config-baremetal.yaml.tpl -p cluster.name=foo

# With schema validation
./process.py data/customer.example.clusterfile templates/agent-config-bond-vlan.yaml.tpl -s schema/clusterfile.schema.json

# Validate data and params (-S shortcut)
./process.py data/customer.example.clusterfile templates/agent-config-bond-vlan.yaml.tpl -s schema/clusterfile.schema.json -S

# Inline JSON data
./process.py '{"cluster":{"name":"inline"}}' templates/agent-config-bond-vlan.yaml.tpl -p network.domain=example.com
```

### Container-based Processing
```bash
# Build container image
podman build -t quay.io/dds/process:latest -f Containerfile

# Use wrapper script (paths must be inside working directory)
./process.sh [data-file] [-p ""]* [template file]
```

### Web Editor
```bash
# Build and run locally
./clusterfile-editor.sh build
./clusterfile-editor.sh

# Release new version (updates APP_VERSION, syncs to main.py and index.html)
./clusterfile-editor.sh release patch   # or minor, major, or x.y.z

# Override image tag
IMAGE_TAG=dev-20250221 ./clusterfile-editor.sh build
```

### Editor Development
```bash
cd apps/editor
poetry install
poetry run pytest
poetry run uvicorn app.main:app --reload
```

## Architecture

### Template Processing Flow
- `process.py` loads YAML data (or inline JSON), applies `-p` JSONPath overrides, optionally validates against JSON schema, then renders Jinja2 templates
- Templates in `templates/` use includes from `templates/includes/`
- YAML output is auto-formatted and linted with yamllint
- Custom Jinja2 filters: `base64encode`, `load_file()` for reading external files

### Clusterfile Schema
- `schema/clusterfile.schema.json` defines the data model for OpenShift cluster configurations
- Top-level sections: `account`, `cluster`, `network`, `hosts`, `plugins`
- `x-is-file` fields indicate paths that templates will read via `load_file()`
- `hosts` uses `patternProperties` keyed by hostname

### Web Editor Architecture
- FastAPI backend (`apps/editor/app/main.py`) serves static files and API endpoints
- Frontend uses CodeMirror for YAML editing, AJV for client-side validation
- API endpoints: `/api/schema`, `/api/samples`, `/api/templates`, `/api/render`
- Version tracked in `apps/editor/APP_VERSION` and synced to `main.py`/`index.html` on build

### Data Examples
- Sample clusterfiles in `data/` demonstrate different configurations:
  - `customer.example.clusterfile` - Basic
  - `customer.example.vlan.clusterfile` - VLAN-only
  - `customer.example.bond.clusterfile` - Bond-only
  - `customer.example.bond.vlan.clusterfile` - Bond + VLAN
  - `customer.example.nutanix.clusterfile` - Nutanix platform
