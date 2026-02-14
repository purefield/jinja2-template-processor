# Clusterfile Template Processor

A Jinja2 template engine for generating OpenShift and Kubernetes configuration from declarative YAML clusterfiles. One data file describes your entire cluster — the processor renders installation manifests, ACM policies, operator subscriptions, and pre-flight checks.

**Web editor**: [quay.io/dds/clusterfile-editor](https://quay.io/repository/dds/clusterfile-editor) — schema-driven, offline-first UI for editing clusterfiles in a browser.

## How it works

```
clusterfile (YAML)  +  template (.yaml.tpl)  →  rendered output
```

A **clusterfile** contains all cluster parameters: name, version, platform, networking, hosts, storage, BMC credentials, operator plugins. A **template** consumes the clusterfile and produces Kubernetes-ready YAML — install configs, agent configs, ACM resources, operator manifests, shell scripts.

```bash
# Render an install-config.yaml for agent-based install
./process.py data/baremetal-bond-vlan.clusterfile templates/install-config.yaml.tpl

# Render ACM ZTP manifests for managed cluster provisioning
./process.py data/baremetal.clusterfile templates/acm-ztp.yaml.tpl

# Render all operator manifests for post-install
./process.py data/acm-hub-sno.clusterfile templates/operators.yaml.tpl
```

## Quick start

### Requirements

- Python 3.8+
- pip

### Install

```bash
pip install jinja2 pyyaml yamllint jsonpath-ng jsonschema
```

### Render your first template

```bash
# Clone and enter the repo
git clone https://github.com/purefield/jinja2-template-processor.git
cd jinja2-template-processor

# Render an install-config for a baremetal cluster
./process.py data/baremetal.clusterfile templates/install-config.yaml.tpl
```

## Use cases

### Agent-Based Install (ABI)

Generate `install-config.yaml` and `agent-config.yaml` for the OpenShift agent-based installer:

```bash
./process.py data/baremetal-bond-vlan.clusterfile templates/install-config.yaml.tpl > install-config.yaml
./process.py data/baremetal-bond-vlan.clusterfile templates/agent-config.yaml.tpl > agent-config.yaml
```

### IPI (Installer Provisioned Infrastructure)

Generate platform-specific install configs for cloud providers:

```bash
# AWS
./process.py data/ipi-aws.clusterfile templates/install-config.yaml.tpl

# vSphere with static IPs
./process.py data/ipi-vsphere.clusterfile templates/install-config.yaml.tpl

# Azure, GCP, Nutanix, OpenStack, IBM Cloud — same pattern
./process.py data/ipi-azure.clusterfile templates/install-config.yaml.tpl
```

### ACM Zero Touch Provisioning (ZTP)

Generate all resources for ACM-managed bare metal provisioning — Namespace, Secrets, AgentClusterInstall, ClusterDeployment, BareMetalHosts, NMState configs, InfraEnv:

```bash
./process.py data/baremetal.clusterfile templates/acm-ztp.yaml.tpl > acm-ztp.yaml
oc apply -f acm-ztp.yaml
```

### ACM CAPI + Metal3

Generate Cluster API resources with the Metal3 provider:

```bash
./process.py data/baremetal.clusterfile templates/acm-capi-m3.yaml.tpl > acm-capi-m3.yaml
oc apply -f acm-capi-m3.yaml
```

### Day-2 Operators

Generate operator installation manifests for post-install application:

```bash
# All configured operators as standalone manifests
./process.py data/acm-hub-sno.clusterfile templates/operators.yaml.tpl > operators.yaml
oc apply -f operators.yaml
```

Operators are also automatically included as:
- **ABI extra manifests** in `install-config.yaml.tpl`
- **ACM Policies** in `acm-ztp.yaml.tpl` and `acm-capi-m3.yaml.tpl`

### KubeVirt (OpenShift Virtualization)

Generate VirtualMachine resources for OpenShift Virtualization clusters:

```bash
./process.py data/kubevirt.clusterfile templates/kubevirt-cluster.yaml.tpl
```

### Pre-flight Checks

Generate validation scripts for DNS, NTP, BMC, network, and registry connectivity:

```bash
# All checks
./process.py data/baremetal.clusterfile templates/pre-check.sh.tpl | bash

# Individual checks
./process.py data/baremetal.clusterfile templates/pre-check-dns.sh.tpl | bash
./process.py data/baremetal.clusterfile templates/pre-check-bmc.sh.tpl | bash
```

## Clusterfile anatomy

A clusterfile has four main sections:

```yaml
account:
  pullSecret: path/to/pull-secret.json    # Red Hat pull secret

cluster:
  name: my-cluster
  version: "4.21.0"
  platform: baremetal                       # baremetal, none, aws, azure, gcp, vsphere, ...
  arch: x86_64
  sshKeys:
    - path/to/id_rsa.pub
  location: dc1

network:
  domain: example.com
  primary:
    gateway: 10.0.0.1
    subnet: 10.0.0.0/24
  cluster:
    subnet: 10.128.0.0/14
  service:
    subnet: 172.30.0.0/16

hosts:
  node1.example.com:
    role: control                           # control or worker
    storage:
      os: { deviceName: /dev/sda }
    bmc:
      vendor: dell
      address: 10.0.1.1
      username: root
      password: bmc-password.txt
    network:
      interfaces:
        - name: eno1
          macAddress: "00:1A:2B:3C:4D:01"
      primary:
        address: 10.0.0.10
        ports: [eno1]
```

### Optional sections

```yaml
cluster:
  disconnected: true                        # Air-gapped installation
  tpm: true                                 # TPM disk encryption
  mirrors:                                  # Registry mirrors for disconnected
    - source: registry.redhat.io
      mirrors: [mirror.local/redhat]
  catalogSources:                           # Custom operator catalogs
    - name: custom-operators
      image: mirror.local/catalog:v4.21

network:
  proxy:                                    # Cluster-wide proxy
    httpProxy: http://proxy:8080
    httpsProxy: http://proxy:8080
    noProxy: .cluster.local,10.0.0.0/8
  trustBundle: /path/to/ca-bundle.pem       # Additional trust CA
  secondary:                                # Secondary networks (SR-IOV, bridges)
    - name: storage-net
      type: linux-bridge
      vlan: 100
      ports: [eth1]
      subnet: 192.168.1.0/24

plugins:
  kubevirt:                                 # Platform plugin (KubeVirt example)
    storageClass:
      default: ocs-storagecluster-ceph-rbd
      performance: lvms-vg1
    network:
      type: cudn
  operators:                                # Day-2 operator plugins
    argocd: {}                              # {} = all defaults
    lvm: {}
    acm:
      multiClusterHub:
        availabilityConfig: Basic
    cert-manager: {}
    external-secrets: {}
```

## Operator plugins

Each operator is configured under `plugins.operators.<name>`. Specify `{}` for all defaults, or override individual settings:

| Operator | Key | Default Channel | What it installs |
|----------|-----|-----------------|-----------------|
| [ArgoCD](plugins/operators/argocd/) | `argocd` | `latest` | GitOps operator + ArgoCD instance + optional bootstrap Application |
| [LVM Storage](plugins/operators/lvm/) | `lvm` | `stable` | LVMS operator + LVMCluster with deviceClasses |
| [ODF](plugins/operators/odf/) | `odf` | `stable-4.18` | ODF operator + StorageCluster + ConsolePlugin |
| [ACM](plugins/operators/acm/) | `acm` | `release-2.14` | ACM operator + MultiClusterHub + AgentServiceConfig + Provisioning |
| [cert-manager](plugins/operators/cert-manager/) | `cert-manager` | `stable-v1` | cert-manager operator (install-and-go) |
| [external-secrets](plugins/operators/external-secrets/) | `external-secrets` | `stable-v1` | external-secrets operator (global scope) |

Every operator supports these common overrides:

```yaml
plugins:
  operators:
    lvm:
      channel: stable-4.19        # OLM subscription channel
      source: my-catalog           # Catalog source (disconnected)
      approval: Manual             # InstallPlan approval (Automatic/Manual)
```

Each operator generates two template files:
- **`manifests.yaml.tpl`** — standalone YAML for `oc apply` or ABI extra manifests
- **`policy.yaml.tpl`** — ACM Policy + PlacementBinding for ZTP/CAPI managed clusters

See each operator's README for full configuration reference.

## Platform plugins

Platform plugins configure cloud-specific settings in `install-config.yaml`. They live in `templates/plugins/platforms/` and are selected automatically based on `cluster.platform`:

| Platform | Plugin Config | Templates |
|----------|--------------|-----------|
| AWS | `plugins.aws` | platform, controlPlane, compute, creds |
| Azure | `plugins.azure` | platform, controlPlane, compute, creds |
| GCP | `plugins.gcp` | platform, controlPlane, compute, creds |
| vSphere | `plugins.vsphere` | platform, controlPlane, compute, creds |
| OpenStack | `plugins.openstack` | platform, controlPlane, compute, creds |
| IBM Cloud | `plugins.ibmcloud` | platform, controlPlane, compute, creds |
| Nutanix | `plugins.nutanix` | platform, controlPlane, compute, creds |
| KubeVirt | `plugins.kubevirt` | platform |
| Baremetal | — | platform |
| None (SNO) | — | platform |

## CLI reference

```
./process.py [data-file] [template-file] [options]
```

| Flag | Description |
|------|-------------|
| `-p key=value` | Override or create a field (dotted path: `-p cluster.name=foo`) |
| `-s schema.json` | Validate input against JSON Schema |
| `-S` | Validate both input and after `-p` overrides |

### Inline JSON

```bash
./process.py '{"cluster":{"name":"inline"}}' templates/install-config.yaml.tpl
```

### Parameter-only mode

```bash
./process.py templates/install-config.yaml.tpl -p cluster.name=test -p cluster.version=4.21.0
```

## Web editor

The Clusterfile Editor is a browser-based UI for editing clusterfiles with schema-driven forms, live YAML preview, and template rendering.

### Run from container

```bash
podman run -d --name clusterfile-editor -p 8000:8000 quay.io/dds/clusterfile-editor:latest
# Open http://localhost:8000
```

### Build from source

```bash
# From repo root
podman build -t clusterfile-editor -f apps/editor/Containerfile .
podman run -d --name clusterfile-editor -p 8000:8000 clusterfile-editor
```

### Development mode

```bash
cd apps/editor
pip install fastapi[standard] jinja2 yamllint jsonpath-ng jsonschema pyyaml uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Container image (CLI)

Use the CLI processor as a container:

```bash
# Build
podman build -t quay.io/dds/process:latest -f Containerfile .

# Run (mount your data directory)
podman run --rm -v ./data:/data:Z quay.io/dds/process:latest \
  /data/baremetal.clusterfile templates/install-config.yaml.tpl
```

## Example clusterfiles

| File | Description |
|------|-------------|
| `data/sno.clusterfile` | Single Node OpenShift with LVM + ArgoCD, disconnected, mirrors |
| `data/acm-hub-sno.clusterfile` | ACM hub on SNO with all 6 operators |
| `data/baremetal.clusterfile` | Standard 3-node baremetal cluster |
| `data/baremetal-bond-vlan.clusterfile` | Baremetal with bonded NICs + VLANs |
| `data/baremetal-compact.clusterfile` | 3-node compact cluster (no workers) |
| `data/kubevirt.clusterfile` | KubeVirt cluster with CUDN networking |
| `data/kubevirt-sno.clusterfile` | KubeVirt SNO |
| `data/ipi-aws.clusterfile` | AWS IPI |
| `data/ipi-vsphere.clusterfile` | vSphere IPI with static IPs |
| `data/ipi-nutanix.clusterfile` | Nutanix IPI |

## Project structure

```
.
├── process.py                          # CLI template processor
├── schema/
│   └── clusterfile.schema.json         # JSON Schema for clusterfile validation
├── data/                               # Example clusterfiles
├── templates/                          # Jinja2 templates (.yaml.tpl)
│   ├── includes/                       # Reusable template fragments (nmstate, bmc, etc.)
│   └── plugins/platforms/              # Platform-specific includes (aws, vsphere, etc.)
├── plugins/
│   └── operators/                      # Operator plugins (co-located schema + templates)
│       ├── argocd/                     # ArgoCD operator
│       ├── lvm/                        # LVM Storage operator
│       ├── odf/                        # OpenShift Data Foundation
│       ├── acm/                        # Advanced Cluster Management
│       ├── cert-manager/               # cert-manager operator
│       └── external-secrets/           # external-secrets operator
├── apps/
│   └── editor/                         # Web editor (FastAPI + vanilla JS)
└── tests/
    └── test_templates.py               # 95 pytest tests
```

## Schema validation

The clusterfile schema (`schema/clusterfile.schema.json`) validates all sections including operator plugins. The web editor uses it for form generation; the CLI uses it with `-s`:

```bash
./process.py data/sno.clusterfile templates/install-config.yaml.tpl \
  -s schema/clusterfile.schema.json -S
```

## Tests

```bash
pip install pytest
python3 -m pytest tests/ -v
```

95 tests covering install-config, agent-config, credentials, platform includes, KubeVirt, ACM ZTP, ACM CAPI, disconnected mode, TPM, insecure mirrors, and all 6 operator plugins.

## License

MIT
