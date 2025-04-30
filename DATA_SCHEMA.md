# YAML Data Schema - https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/installing_an_on-premise_cluster_with_the_agent-based_installer/preparing-to-install-with-agent-based-installer

```yaml
account:
  pullSecret: string (required)

cluster:
  version: string (required)
  name: string (required)
  sshKeys: [string, string] (required)
  location: string (required)
  manifests: [string, string] (optional)

network:
  domain: string (required)
  trustBundle: string (optional)

  proxy:
    httpProxy: string (optional)
    httpsProxy: string (optional)
    noProxy: string (optional)

  ntpservers:
    - string

  nameservers:
    - string

  dnsResolver:
    search:
      - string

  primary:
    bond: "802.3ad" | "active-backup" | false
    vlan: integer (1-4094) | false
    mtu: integer
    gateway: string
    subnet: string
    vips:
      api:
        - string
      apps:
        - string

  cluster:
    subnet: string
    hostPrefix: integer

  service:
    subnet: string

hosts:
  <hostname>:
    role: "control" | "worker"
    storage:
      os:
        wwn: string
        deviceName: string
        hctl: string
        model: string
        vendor: string
        serialNumber: string
        minSizeGigabytes: integer
        rotational: boolean
    bmc:
      vendor: string
      username: string
      password: string
      address: string
    network:
      interfaces:
        - name: string
          macAddress: string
      primary:
        address: string
        ports:
          - string
```
### Files to import

- account.pullSecret
- cluster.trustBundle
- host.*.bmc.password
- cluster.sshKeys
- cluster.manifests


### Valid Bond Types

- `active-backup`
- `balance-rr`
- `802.3ad`
- `balance-xor`
- `broadcast`
- `balance-tlb`
- `balance-alb`

### VLAN

- Range: 1–4094

### MTU

- 1500 (standard)
- 9000 (jumbo frames)

### Host Prefix

- Example: 23 (allows 512 hosts in a /16 network)
