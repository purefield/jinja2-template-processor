# python jinja2-template-processor

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
