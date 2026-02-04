# Template: install-config-baremetal.yaml.tpl

Generates the OpenShift `install-config.yaml`.

## Required Fields

- cluster (version, name, sshKeys)
- account.pullSecret
- network:
  - domain, trustBundle
  - proxy, nameservers, ntpservers
  - primary: bond, vlan, mtu, gateway, subnet, vips
  - cluster.subnet + hostPrefix
  - service.subnet
- hosts (FQDNs, role, network interfaces, storage)
