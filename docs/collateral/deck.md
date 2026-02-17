# Clusterfile: One Definition, Every Deployment Method

*Presentation Deck — 11 Slides*

---

## Slide 1: Title

# Clusterfile

### One definition, every deployment method

A declarative cluster intent format + template processor + web editor for OpenShift

---

## Slide 2: The Problem — Configuration Sprawl

### One cluster, five files, five formats

```
┌──────────────────────┐
│   OpenShift Cluster   │
│   "prod-east-01"      │
└──────────┬───────────┘
           │
     ┌─────┼─────┬──────────┬──────────┬──────────┐
     ▼     ▼     ▼          ▼          ▼          ▼
  install  agent  ACM ZTP   SiteConfig  operators  pre-checks
  -config  -config manifests CR         .yaml      .sh
  .yaml    .yaml  (5 CRs)              (6 subs)   (6 scripts)
```

- Each file has its own format, its own assumptions, its own gotchas
- A single network change touches 3+ files
- No validation across files — mismatches cause silent failures
- Copy-paste between clusters drifts over time

**Result:** Fragile installs, slow onboarding, tribal knowledge

---

## Slide 3: The Insight

### Same data, different formats

Every deployment method needs the same information:

| Data | install-config | ACM ZTP | SiteConfig | operators.yaml |
|------|:-:|:-:|:-:|:-:|
| Cluster name | Yes | Yes | Yes | Yes |
| Network config | Yes | Yes | Yes | — |
| Host BMC creds | — | Yes | Yes | — |
| Platform details | Yes | Yes | Yes | — |
| Operator config | — | — | — | Yes |

The **cluster intent** is constant. Only the **output format** changes.

---

## Slide 4: The Solution

### Clusterfile → Template → Any Output

```
                              ┌─ install-config.yaml (IPI/ABI)
                              ├─ agent-config.yaml
  ┌─────────────────┐         ├─ ACM ZTP (InfraEnv, ClusterDeployment,
  │  clusterfile    │         │           BareMetalHost, NMState)
  │  .yaml          │────────►├─ ACM CAPI (Metal3 provider)
  │                 │         ├─ SiteConfig ClusterInstance CR
  │  One file.      │         ├─ operators.yaml (6 operators)
  │  All the intent.│         ├─ pre-check.sh (DNS, NTP, BMC, network)
  │  Schema-valid.  │         ├─ cluster-overview.html
  └─────────────────┘         └─ creds.yaml (platform credentials)
```

- **Define once** — single YAML clusterfile with external file references
- **Externalize** — pull secrets, SSH keys, certificates, credentials, and manifests are file paths — the processor reads and inlines them at render time
- **Render many** — 102 Jinja2 templates across 6 deployment methods
- **Validate always** — JSON Schema catches errors before they reach the cluster

---

## Slide 5: Architecture

### CLI + Editor + Templates + Plugins

```
┌─────────────────────────────────────────────────────┐
│                   Web Editor (v3.3.0)                │
│  Schema-driven form │ YAML editor │ Live rendering  │
└────────────────────────────┬────────────────────────┘
                             │ /api/render
┌────────────────────────────▼────────────────────────┐
│              Template Processor (CLI + API)          │
│                    process.py (402 LOC)              │
└───────┬──────────────┬──────────────┬───────────────┘
        │              │              │
┌───────▼──────┐ ┌─────▼──────┐ ┌────▼────────────┐
│  33 Core     │ │ 11 Platform│ │  6 Operator     │
│  Templates   │ │ Plugins    │ │  Plugins        │
│              │ │            │ │                  │
│ install-cfg  │ │ AWS        │ │ ArgoCD          │
│ agent-cfg    │ │ Azure      │ │ LVM Storage     │
│ ACM ZTP      │ │ GCP        │ │ ODF             │
│ SiteConfig   │ │ vSphere    │ │ ACM             │
│ pre-checks   │ │ OpenStack  │ │ cert-manager    │
│ operators    │ │ IBM Cloud  │ │ external-secrets│
│ kubevirt     │ │ Nutanix    │ │                 │
│ overview     │ │ Baremetal  │ │ Each: manifests │
│              │ │ KubeVirt   │ │ + ACM policy    │
│              │ │ None (SNO) │ │ + config        │
│              │ │ External   │ │                 │
└──────────────┘ └────────────┘ └─────────────────┘
                       │
               ┌───────▼───────┐
               │  JSON Schema  │
               │  (~99KB)      │
               │  Auto-discover│
               │  operator     │
               │  schemas      │
               └───────────────┘
```

---

## Slide 6: Web Editor — Schema-Driven Editing

### Live editing with instant feedback

**Left pane — Schema-driven form:**
- Auto-generated from JSON Schema
- Collapsible sections: Account, Cluster, Network, Hosts, Plugins
- Real-time validation with inline error messages
- Platform-aware: fields adapt when you change the platform

**Right pane — YAML code editor:**
- CodeMirror with syntax highlighting, code folding
- Bidirectional sync with the form
- Load/save clusterfiles, import samples for all 11 platforms

**Bottom pane — Template rendering:**
- Select any of 102 templates, render instantly
- Copy output, review before applying

**Privacy:** Offline-first. No telemetry. No data leaves the browser. CSP-hardened.

---

## Slide 7: Template Coverage Matrix

### 102 templates across 11 platforms and 6 deployment methods

| Output | BM | KV | AWS | Azure | GCP | vSphere | OStack | IBM | Nutanix | None | Ext |
|--------|:--:|:--:|:---:|:-----:|:---:|:-------:|:------:|:---:|:-------:|:----:|:---:|
| install-config | X | X | X | X | X | X | X | X | X | X | X |
| agent-config   | X | X | — | — | — | — | — | — | — | X | — |
| ACM ZTP        | X | — | — | — | — | — | — | — | — | — | — |
| ACM CAPI       | X | — | — | — | — | — | — | — | — | — | — |
| SiteConfig     | X | X | — | — | — | — | — | — | — | X | — |
| operators      | X | X | X | X | X | X | X | X | X | X | X |
| pre-checks     | X | — | — | — | — | — | — | — | — | — | — |
| creds          | — | — | X | X | X | X | X | X | X | — | — |
| overview       | X | X | X | X | X | X | X | X | X | X | X |

**Operator coverage:** ArgoCD, LVM Storage, ODF, ACM, cert-manager, External Secrets — each with standalone manifests + ACM Policy wrapper

---

## Slide 8: File Externalization + Day-2 Secrets

### Build time: file references. Runtime: Vault + ESO on the created cluster.

**At authoring time** — the clusterfile keeps large or sensitive content out of YAML:

```
clusterfile.yaml                     External files (on disk)
─────────────────                    ────────────────────────
account:
  pullSecret: ~/pull-secret.json ──► {"auths":{"quay.io":{...}}}  (3KB)
cluster:
  sshKeys:
    - ~/.ssh/id_ed25519.pub ───────► ssh-ed25519 AAAA...          (100B)
network:
  trustBundle: ~/ca-bundle.pem ────► -----BEGIN CERTIFICATE-----  (4KB)
hosts:
  node1:
    bmc:
      password: ~/bmc.pass ────────► Sup3rS3cret                  (11B)
```

The processor calls `load_file()` at render time — content is read, trimmed, indented, and inlined into the output. The clusterfile stays compact, readable, and safe to commit.

**At day-2 runtime** — ESO runs *on the created cluster* (not during rendering):

```
Vault / OpenBao ──► External Secrets Operator ──► Kubernetes Secrets
(external store)    (deployed to cluster)          (on the cluster)
```

- Clusterfile generates the ESO Subscription + ClusterSecretStore manifests
- After the cluster is up, ESO syncs secrets from Vault into Kubernetes Secrets
- cert-manager uses an ExternalSecret to pull Route53 credentials from Vault for DNS-01 ACME
- ESO is **not** involved in clusterfile rendering — it's a runtime operator for the cluster itself

---

## Slide 9: Validated In Production

### 134 tests. 11 platforms. Real deployments.

**Test coverage:**
- Every platform × every deployment method combination
- All 6 operators: standalone + ACM policy variants
- Network: bonding, VLANs, secondary networks, proxy, disconnected
- Security: TPM encryption, Tang encryption, file externalization, day-2 Vault/ESO
- Topologies: SNO, compact, HA, HA+arbiter, KubeVirt

**Production deployments:**
- Baremetal clusters: bonded NICs, VLANs, TPM disk encryption
- KubeVirt clusters: CUDN networking, linux-bridge, SSD udev rules
- Cloud IPI: AWS, Azure, GCP, vSphere
- Disconnected: mirror registries, custom catalog sources
- ACM-managed fleets: ZTP automation, operator policies

**Maturity:**
- 50+ tagged releases since v2.6.6
- Comprehensive changelog and audit trail
- Container image on Quay.io with health endpoint

---

## Slide 10: Roadmap

### Where Clusterfile is heading

**Near-term:**
- GitOps delivery via ArgoCD — clusterfiles in Git, rendered by CI, applied by ArgoCD
- Multi-cluster fleet management — parameterized clusterfiles for cluster families
- Additional operator plugins — GitOps Operator, Logging, Monitoring, Compliance

**Medium-term:**
- Cluster lifecycle — day-2 operations (upgrade, scale, rotate secrets) from the same clusterfile
- Drift detection — compare running cluster state against clusterfile intent
- Import existing clusters — reverse-render a clusterfile from a live cluster

**Long-term:**
- Multi-vendor support — beyond OpenShift to upstream Kubernetes, EKS, AKS, GKE
- Policy-as-code — embed compliance rules (CIS, NIST) directly in the schema
- Fleet dashboard — visual management of clusterfile-defined clusters

---

## Slide 11: Call to Action

### Try it now

1. **Web Editor:** Pull the container and open in your browser
   ```
   podman run -d -p 8000:8000 quay.io/dds/clusterfile-editor:latest
   ```

2. **CLI:** Render a template from an example clusterfile
   ```
   python process.py -t install-config.yaml.tpl -d data/baremetal.clusterfile
   ```

3. **Explore:** Load a sample, change the platform, render different outputs

### Get involved

- Browse the template library — find gaps, suggest new outputs
- Try your cluster config — convert an existing install-config to a clusterfile
- Integrate into your workflow — CI/CD, GitOps, fleet provisioning

### Contact

*[Your team / Slack channel / email here]*
