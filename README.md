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

## Render acm-ztp.yaml
Configuration file for ACM zero touch provisioning
```bash
./process.py data/customer.example.bond.vlan.yaml templates/acm-ztp.yaml.tpl > acm-ztp.yaml
cat acm-ztp.yaml
```

## Render acm-asc.yaml
Configuration file for ACM Agent Service Config
```bash
./process.py data/customer.example.bond.vlan.yaml templates/acm-asc.yaml.tpl > acm-asc.yaml
cat acm-asc.yaml
```

## Render test-dns.sh
Create forward and reverse DNS verification script
```bash
./process.py data/customer.example.bond.vlan.yaml templates/test-dns.sh.tpl | bash
```
## Render infinibox-machine-config.yaml.tpl
This generates the infinidat machine configuration files with the configured content
```bash
./process.py data/infinidat.yaml templates/infinibox-machine-config.yaml.tpl
```
## Render acm-creds.yaml.tpl
This generates the hostinventory credentials for ACM
```bash
./process.py data/customer.example.yaml templates/acm-creds.yaml.tpl > acm-creds.yaml
cat acm-creds.yaml
```

## Data Models
- Standard: `customer.example.yaml`
- VLAN only: `customer.example.vlan.yaml`
- Bond only: `customer.example.bond.yaml`
- Bond + VLAN: `customer.example.bond.vlan.yaml`
