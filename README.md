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
