# Template: agent-config-bond-vlan.yaml.tpl

Creates a node-specific AgentConfig CR supporting bonding and VLAN.

## Required Fields

- Same as install-config but focus on per-host bonding
- network.primary.bond: must be string (e.g. "802.3ad")
- network.primary.vlan: must be integer (e.g. 1234)
