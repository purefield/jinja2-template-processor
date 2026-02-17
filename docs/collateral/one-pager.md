# Clusterfile: One Definition, Every Deployment Method

## The Problem

Deploying an OpenShift cluster requires maintaining parallel configurations across multiple tools. A single cluster easily spans 500+ lines across 5+ files — install-config for the installer, ACM policies for ZTP, CAPI manifests, SiteConfig CRs, operator subscriptions, pre-check scripts — each with its own format and assumptions. Changes mean updating every file. Mistakes mean failed installs.

## The Insight

The cluster intent is the same regardless of deployment method. What changes is the output format, not the data.

## The Solution

**Clusterfile** — one YAML file describing a complete cluster: identity, networking, hosts, storage, and operators. A Jinja2 template processor renders it into any target format. A schema-driven web editor makes it accessible to anyone.

Large or sensitive content — pull secrets, SSH keys, CA certificates, cloud credentials, BMC passwords, extra manifests — is **externalized into files** on disk. The clusterfile stores only the file path; the processor reads and inlines the content at render time. This keeps the clusterfile compact and readable while secrets never live in YAML.

```
                          ┌─ install-config.yaml
                          ├─ agent-config.yaml
   clusterfile.yaml ──────├─ ACM ZTP manifests
   (one file, all data)   ├─ SiteConfig ClusterInstance
                          ├─ operators.yaml
                          ├─ pre-check.sh
                          └─ cluster-overview.html
```

## How It Works

1. **Define** your cluster in a single YAML clusterfile — platform, network, hosts, operators
2. **Externalize** large content — pull secrets, SSH keys, certificates, and credentials are file paths, not inline blobs
3. **Validate** against a comprehensive JSON Schema (in the editor or CLI)
4. **Render** any template — the processor reads external files and fills in platform-specific details automatically
5. **Deploy** — pipe the output to `oc apply`, feed it to the installer, or commit to Git

## By the Numbers

| | |
|---|---|
| **102 templates** | Covering installation, ACM ZTP, CAPI, SiteConfig, operators, pre-checks, and docs |
| **11 platforms** | AWS, Azure, GCP, vSphere, OpenStack, IBM Cloud, Nutanix, Baremetal, KubeVirt, None (SNO), External |
| **6 deployment methods** | Agent-based, IPI, ACM ZTP, ACM CAPI, UPI, SiteConfig |
| **6 operator plugins** | ArgoCD, LVM Storage, ODF, ACM, cert-manager, External Secrets (ESO) |
| **134 automated tests** | Every platform, topology, and feature combination |
| **19 example clusterfiles** | Ready-to-use samples for every platform and topology |

## Differentiators

| Capability | Clusterfile | Helm | Kustomize | Ansible |
|---|:---:|:---:|:---:|:---:|
| Single source of truth for all outputs | Yes | No | No | No |
| Multi-target rendering (installer + ACM + operators) | Yes | No | No | Partial |
| Schema-validated web editor | Yes | No | No | No |
| Offline-first, no telemetry | Yes | N/A | N/A | N/A |
| Bidirectional SiteConfig conversion | Yes | No | No | No |
| Externalized file references (secrets, certs) | Yes | No | No | No |
| Day-2 secrets management (Vault/ESO templates) | Yes | No | No | Partial |

## Architecture

- **CLI** (`process.py`) — Render any template from the command line; pipe to `oc apply` or write to file
- **Web Editor** — Schema-driven browser UI with live YAML editing, validation, and template rendering
- **Template Library** — 102 Jinja2 templates organized by function (install, ACM, operators, scripts)
- **Plugin System** — Platform plugins (11) and operator plugins (6) with auto-discovered schemas
- **File Externalization** — Pull secrets, SSH keys, certificates, cloud credentials, and manifests are file paths in the clusterfile; the processor reads and inlines them at render time
- **Day-2 Operator Templates** — Generates ESO + Vault ClusterSecretStore manifests for the created cluster's own secrets management (ESO runs on the cluster, not during rendering)

## Validated In Production

- Baremetal clusters with bonded NICs, VLANs, and TPM disk encryption
- KubeVirt (OpenShift Virtualization) clusters with CUDN and linux-bridge networking
- Cloud IPI deployments on AWS, Azure, GCP, vSphere
- Disconnected/air-gapped environments with mirror registries
- ACM-managed multi-cluster fleets with ZTP automation

---

**Get started:** Load a sample clusterfile in the web editor, change the platform, and render any template.
