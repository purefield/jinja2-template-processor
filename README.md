# python jinja2-template-processor
## YAML Jinja Template Processor Setup
This script renders Jinja2 templates using YAML data and validates the result with `yamllint`.

## 🧰 Requirements
- Python 3.6+
- pip (Python package manager)

## 📦 Install Dependencies
```bash
pip install -r requirements.txt
```

## Render agent-config.yaml
```bash
./process.py data/customer.example.bond.vlan.yaml templates/agent-config-bond-vlan.yaml.tpl   > agent-config.yaml
cat agent-config.yaml
```

## Render install-config.yaml
```bash
./process.py data/customer.example.bond.vlan.yaml templates/install-config-baremetal.yaml.tpl > install-config.yaml
cat install-config.yaml
```

## Data Models
- Standard: `customer.example.yaml`
- VLAN only: `customer.example.vlan.yaml`
- Bond only: `customer.example.bond.yaml`
- Bond + VLAN: `customer.example.bond.vlan.yaml`