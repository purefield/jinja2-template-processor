# python jinja2-template-processor
## YAML Jinja Template Processor Setup
This script renders Jinja2 templates using YAML input data and parameters in jsonpath format.
When the template is producing yaml, it validates the result with `yamllint`.

## 🧰 Requirements
- Python 3.6+
- pip (Python package manager)

## 📦 Install Dependencies
```bash
pip install -r requirements.txt
```

## 📦 Use as container image
Create container image
```bash
podman build -t quay.io/dds/process:latest -f Containerfile
podman login quay.io/dds
podman push quay.io/dds/process:latest
```
Use wrapper script with container image (all path need to be inside the working directory)
```bash
process.sh [data-file] [-p ""]* [template file]
```


# Examples
## Agent Based Installer
### Render agent-config.yaml
```bash
./process.py data/customer.example.bond.vlan.yaml templates/agent-config-bond-vlan.yaml.tpl   > agent-config.yaml
cat agent-config.yaml
```
### Render install-config.yaml
```bash
./process.py data/customer.example.bond.vlan.yaml templates/install-config-baremetal.yaml.tpl > install-config.yaml
cat install-config.yaml
```
### Render install-config.yaml for Nutanix
```bash
./process.py data/customer.example.nutanix.yaml templates/install-config-baremetal.yaml.tpl > install-config.yaml
cat install-config.yaml
```
### Render mirror-registry-config.yaml
```bash
mkdir openshift
./process.py data/customer.example.bond.vlan.yaml templates/mirror-registry-config.yaml.tpl > openshift/mirror-registry-config.yaml
cat openshift/mirror-registry-config.yaml
```

## Advanced Cluster Management Host Inventory ZTP Installation
### Render acm-ztp.yaml
Configuration file for ACM zero touch provisioning
```bash
./process.py data/customer.example.bond.vlan.yaml templates/acm-ztp.yaml.tpl > acm-ztp.yaml
cat acm-ztp.yaml
```

## CAPI+Metal3 Installation using MCE
### Render acm-capi-m3.yaml
Configuration file for ACM zero touch provisioning
```bash
./process.py data/customer.example.bond.vlan.yaml templates/acm-capi-m3.yaml.tpl > acm-capi-m3.yaml
cat acm-capi-m3.yaml
```

### Render acm-asc.yaml
Configuration file for ACM Agent Service Config
```bash
./process.py data/customer.example.bond.vlan.yaml templates/acm-asc.yaml.tpl > acm-asc.yaml
cat acm-asc.yaml
```
## Render acm-creds.yaml.tpl
This generates the hostinventory credentials for ACM
```bash
./process.py data/customer.example.yaml templates/acm-creds.yaml.tpl > acm-creds.yaml
cat acm-creds.yaml
```

## Render test-dns.sh
Create forward and reverse DNS verification script
```bash
./process.py data/customer.example.bond.vlan.yaml templates/test-dns.sh.tpl | bash
```
## Render infinidat-setup.yaml.tpl
This generates the infinidat machine, operator, driver configuration files with the configured content
```bash
./process.py data/infinidat.yaml templates/infinidat-setup.yaml.tpl
```
## Render secondary-network-setup.yaml.tpl
This generates secondary network configuration based on network.secondary list
```bash
./process.py data/infinidat.yaml templates/secondary-network-setup.yaml.tpl
```
### any reason to prever ovn vs linux bridge?
* if micro-segmentation comes up AND/OR any type of firewalling for VLAN based networks use OVNK localnet + MultiNetworkPolicy (linux-bridge does not support it)
* If possible avoid creating bridge mappings for br-ex bridge and use dedicated NICs/bonds (dont pollute OCP control plane traffic with VM dataplane)
* If VMs need to be attached to the same VLAN as machineNetwork, must use ONK localnet with br-ex bridge mappings
* Always advocate for bonds VS single NICs for VM dataplane traffic
* live migration network should use a dedicated NIC and preferably a macvlan (it offers best perfomance)
* if VM guest tagging is required must use linux-bridge (it allows disabling mac spoofing where as OVNK localnet does not)
* if there is no DHCP available but they want to auto assign IPs to VMs, must use linux-bridge (only linux-bridge supports openshift ipam with whereabouts)
* For VNF use cases with service-chaining must use linux-bridge (when routing is required only linux-bridge allows disabling mac spoofing where as OVNK localnet does not)

## Data Models
- Standard: `customer.example.yaml`
- VLAN only: `customer.example.vlan.yaml`
- Bond only: `customer.example.bond.yaml`
- Bond + VLAN: `customer.example.bond.vlan.yaml`
---

## JSON/CLI Data Sources

### Inline JSON as `data_file`
You can pass inline JSON instead of a file:
```bash
./process.py '{"cluster":{"name":"inline"}}' templates/console-notification.yaml.tmpl -p color=red
```

If it parses as JSON, it will be used directly; otherwise it is treated as a filename.

### No file, only `-p`
If you omit `data_file`, an empty object is created and seeded from `-p`:
```bash
./process.py templates/console-notification.yaml.tmpl -p cluster.name=foo -p color=red
```

## Create-if-missing overrides
`-p` supports creating missing paths using dotted keys and `[index]`:
```bash
./process.py '{}' templates/console-notification.yaml.tmpl -p cluster.name=foo -p items[0].key=value
```

## Schema validation

You can validate input data against a JSON Schema using `-s` / `--schema`.
To validate both the original data and again after applying `-p` overrides, use the `-S` flag (no argument) or the long form `--validate-scope data+params`.

Validate data only:
```bash
./process.py data/customer.example.bond.vlan.yaml templates/agent-config-bond-vlan.yaml.tpl -s clusterfile.schema.json
```

Validate data and overrides (shortcut `-S`):
```bash
./process.py data/customer.example.bond.vlan.yaml templates/agent-config-bond-vlan.yaml.tpl -s clusterfile.schema.json -S
```

Notes:
- `-s` accepts a path to a JSON or YAML schema file.
- `-S` is a shortcut flag equivalent to `--validate-scope data+params`.
