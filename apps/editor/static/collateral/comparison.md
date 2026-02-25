# Clusterfile vs. Alternatives — Comparison Matrix

## Overview

This comparison evaluates Clusterfile against common tools used for OpenShift/Kubernetes cluster provisioning and configuration management.

## Feature Comparison

| Capability | Clusterfile | Helm | Kustomize | Ansible (AAP) | SiteConfig (ACM) |
|---|:---:|:---:|:---:|:---:|:---:|
| **Single source of truth for cluster** | One YAML file describes the entire cluster | No — per-chart values, not cluster-wide | No — per-overlay patches | Partial — inventory + playbooks + vars | Partial — ClusterInstance CR only |
| **Multi-target rendering** | 6 methods: IPI, ABI, ZTP, CAPI, SiteConfig, UPI | No — one chart = one output | No — one overlay = one output | Partial — different playbooks per target | No — SiteConfig format only |
| **Multi-platform support** | 11 platforms (cloud + on-prem + virtual) | Per-chart, not unified | Per-overlay, not unified | Yes, via roles/collections | Baremetal + limited cloud |
| **Schema validation** | JSON Schema (99KB), real-time in editor | values.schema.json (optional, rare) | No built-in schema | No built-in schema | CRD validation only |
| **Web editor** | Schema-driven form + YAML + live rendering | No | No | AWX/AAP web UI (workflow-focused) | No |
| **Offline-first** | Yes — all logic in browser, no external calls | CLI-only | CLI-only | Requires server/controller | Requires ACM hub |
| **File externalization** | Pull secrets, SSH keys, certs, credentials are file paths — loaded at render time | No — inline values | No — inline values | Vault-encrypted files | No — inline values |
| **Day-2 secrets templates** | Generates ESO + Vault manifests for the created cluster | External (sealed-secrets, etc.) | External | Ansible Vault (different tool) | External |
| **Pre-flight validation** | 6 modular check scripts (DNS, NTP, BMC, etc.) | No | No | Partial — via pre-tasks | No |
| **Bidirectional conversion** | Clusterfile ↔ ClusterInstance CR | No | No | No | One-way (CR → cluster) |
| **GitOps-ready** | Yes — deterministic YAML output, versionable | Yes | Yes | Partial — playbook execution model | Yes |
| **Day-2 operator management** | 7 operators with manifests + ACM policies | Per-chart | Per-overlay | Via roles | Limited |
| **Cluster topology awareness** | SNO, compact, HA, HA+arbiter auto-detection | No | No | Manual | Limited |
| **Disk encryption** | TPM 2.0 + Tang NBDE, auto-generated MachineConfigs | No | No | Manual playbooks | No |
| **Disconnected/air-gapped** | Digest-based mirrors, IDMS/ICSP, custom catalogs, offline editor | No special support | No special support | Yes, with effort | Yes, with effort |
| **Learning curve** | Low — fill in a YAML form, schema guides you | Medium — chart + values + hooks | Medium — bases + overlays + patches | High — playbooks + roles + inventory | Medium — CRDs + ACM concepts |
| **Dependencies** | Python 3, Jinja2, PyYAML | Go, Kubernetes | kubectl | Python, many collections | ACM hub cluster |

## When to Use What

### Use Clusterfile when:
- You manage clusters across multiple platforms (baremetal + cloud + KubeVirt)
- You need the same cluster definition to produce outputs for different tools (installer + ACM + operators)
- You want schema-validated editing with a web UI
- You need pre-flight checks before installation
- You want one file per cluster in Git for auditability
- You operate in disconnected environments and need offline tooling

### Use Helm when:
- You're deploying applications (not provisioning clusters)
- You need lifecycle management (install, upgrade, rollback) for app releases
- Your team already has Helm charts and workflows established

### Use Kustomize when:
- You have a base Kubernetes manifest and need environment-specific patches
- You want to avoid templating and prefer declarative overlays
- You're working within a kubectl-native workflow

### Use Ansible when:
- You need to orchestrate infrastructure beyond Kubernetes (network switches, DNS, IPAM)
- Your provisioning workflow involves imperative steps (firmware updates, BIOS config)
- You have existing Ansible automation and expertise
- Note: Clusterfile and Ansible are complementary — Clusterfile generates the manifests, Ansible orchestrates the workflow

### Use SiteConfig when:
- You're exclusively on ACM and only need ClusterInstance CRs
- You don't need to generate install-config or operator manifests separately
- Note: Clusterfile can generate SiteConfig CRs, so you can use both together

## Architecture Comparison

| Aspect | Clusterfile | Helm | Kustomize | Ansible | SiteConfig |
|---|---|---|---|---|---|
| **Input format** | YAML clusterfile | values.yaml | YAML manifests + patches | YAML inventory + playbooks | ClusterInstance CR |
| **Processing** | Jinja2 templates | Go templates | Strategic merge patch | Python/Jinja2 tasks | ACM controller |
| **Output** | Any YAML/JSON/shell | Kubernetes manifests | Kubernetes manifests | Executed actions | Kubernetes resources |
| **Execution** | CLI or web editor | CLI (helm) | CLI (kubectl) | CLI or AWX/AAP | ACM hub controller |
| **State management** | Stateless (Git) | Release secrets in cluster | Stateless (Git) | Stateful (facts, inventory) | ACM hub state |
| **Extensibility** | Add templates + plugins | Write charts | Write overlays | Write roles/collections | Limited to CRD |

## Complementary Use

Clusterfile is not a replacement for all these tools — it fills a specific gap:

```
┌──────────────────────────────────────────────────────┐
│                 Cluster Lifecycle                      │
│                                                       │
│  ┌─────────┐   ┌─────────┐   ┌──────────┐           │
│  │ Define  │──►│ Render  │──►│ Deploy   │           │
│  │         │   │         │   │          │           │
│  │Cluster- │   │Cluster- │   │ oc apply │           │
│  │file     │   │file CLI │   │ Ansible  │           │
│  │Editor   │   │         │   │ ArgoCD   │           │
│  └─────────┘   └─────────┘   │ ACM/ZTP  │           │
│                               └──────────┘           │
│                                    │                  │
│                               ┌────▼─────┐           │
│                               │ Manage   │           │
│                               │          │           │
│                               │ Helm     │           │
│                               │ ArgoCD   │           │
│                               │ ACM      │           │
│                               └──────────┘           │
└──────────────────────────────────────────────────────┘
```

Clusterfile handles the **define** and **render** phases. Other tools handle **deploy** and **manage**. They work together, not against each other.
