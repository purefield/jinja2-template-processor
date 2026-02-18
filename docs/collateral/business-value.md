# Clusterfile: Business Value & ROI

*Why it matters for Red Hat and our customers*

---

## The Business Problem

Every OpenShift cluster deployment requires hand-crafting multiple configuration files across multiple tools. A single baremetal cluster needs install-config, agent-config, ACM ZTP manifests, operator subscriptions, credential secrets, and pre-flight validation scripts — each in a different format, each with its own rules, each a source of error.

**The cost is real:**

| Pain point | Impact |
|---|---|
| **Configuration sprawl** | A single 267-line cluster definition explodes into 2,700+ lines across 18+ files and 32 Kubernetes resources of 16 different types |
| **Manual authoring errors** | Mismatched field names, wrong resource versions, forgotten cross-references — silent failures that surface during install |
| **Tribal knowledge** | Only experienced engineers know the correct structure for each deployment method; onboarding takes weeks |
| **Platform fragmentation** | 11 platforms x 6 deployment methods x N network topologies = a combinatorial matrix no team can maintain manually |
| **Drift between clusters** | Copy-paste customization means no two clusters are configured the same way, making troubleshooting and compliance audits expensive |
| **Repeated effort** | Every new cluster starts from scratch or from a stale template that may not reflect current best practices |

---

## The Clusterfile Value Proposition

### One file in, everything out

A 267-line clusterfile produces **2,712 lines** of validated, production-ready output — a **10.2x expansion ratio**. The clusterfile captures only the cluster intent (what makes this cluster unique). The templates encode institutional knowledge (how to express that intent in each tool's format).

```
                                          ┌─ install-config.yaml    (105 lines)
                                          ├─ agent-config.yaml      (253 lines)
  clusterfile.yaml ───────────────────────├─ ACM ZTP manifests      (765 lines, 32 resources)
  (267 lines)                             ├─ operators.yaml          (56 lines)
                                          ├─ pre-check scripts      (380 lines)
  Large content externalized:             ├─ troubleshoot script     (337 lines)
  pull-secret, SSH keys, certs,           ├─ cluster overview        (421 lines)
  BMC passwords → file paths on disk      └─ credentials + other    (395 lines)
                                          ─────────────────────────
                                          Total: 2,712 lines
```

Pull secrets, SSH keys, CA certificates, BMC passwords, and cloud credentials are **never inline** — they're file paths that the processor reads at render time. The clusterfile itself is safe to commit, review, and share.

---

## ROI Model

### For Red Hat Consulting & Services

| Activity | Without Clusterfile | With Clusterfile | Savings |
|---|---|---|---|
| **Create cluster config** (first time) | 4-8 hours manual YAML authoring | 30 min fill in clusterfile + render | **80-90%** |
| **Add a new cluster** (same platform) | 2-4 hours copy-paste-modify | 15 min clone + change 5 fields | **85-95%** |
| **Switch deployment method** (e.g. ABI → ZTP) | Start over — different file formats | Re-render with different template | **95%+** |
| **Pre-flight validation** | Custom scripts per engagement | Render pre-check.sh from same clusterfile | **Included free** |
| **Troubleshooting** | Ad-hoc debug commands | Render troubleshoot script, systematic | **Consistent** |
| **Onboarding a new consultant** | Weeks to learn all resource types | Learn one clusterfile format | **Days, not weeks** |

**At scale:** A consultant deploying 10 clusters across 3 platforms saves **40-80 hours** per engagement. For a services organization deploying hundreds of clusters per year, this is **thousands of hours** returned to billable work.

### For Customers

| Benefit | Detail |
|---|---|
| **Reduced deployment failures** | Schema validation catches errors before rendering; 134 regression tests ensure template correctness |
| **Faster time to production** | From cluster definition to `oc apply` in minutes, not days |
| **Operational consistency** | Every cluster from the same template set is structurally identical — no configuration drift |
| **Lower skill barrier** | The web editor's schema-driven form guides users through every field; no need to memorize 16 Kubernetes resource types |
| **Audit trail** | One clusterfile per cluster in Git = complete, diffable history of cluster intent |
| **Platform mobility** | Changing platforms (e.g. baremetal → KubeVirt, or IPI → ZTP) means changing a few fields, not rewriting everything |

---

## Why This Matters for Red Hat

### 1. It makes OpenShift easier to deploy

The #1 barrier to OpenShift adoption is deployment complexity. Customers see 5+ file formats, 6 deployment methods, and platform-specific gotchas. Clusterfile collapses that into one YAML file and a web editor. **Lower the barrier, increase adoption.**

### 2. It encodes and scales expertise

Red Hat's competitive advantage is deep platform expertise. Today that expertise lives in consultants' heads. Clusterfile captures it in templates — every correct cross-reference, every platform-specific default, every NMState bond configuration. **One expert writes a template, every deployment benefits.**

### 3. It reduces support burden

Configuration errors cause the majority of failed installations. Schema validation and pre-flight checks catch these before they reach the cluster. Consistent template output means support engineers see familiar, predictable configurations. **Fewer tickets, faster resolution.**

### 4. It accelerates services delivery

A consulting engagement that spends 2 days on cluster configuration could spend 2 hours. The freed time goes to architecture, application migration, and higher-value work. **More value per engagement, higher customer satisfaction.**

### 5. It creates a path to fleet management

One clusterfile per cluster, version-controlled in Git, rendered by CI, applied by ArgoCD — this is the foundation for managing 10, 100, or 1000 clusters consistently. **Today: single clusters. Tomorrow: fleet-scale GitOps.**

---

## Proof Points

| Evidence | Detail |
|---|---|
| **10.2x output ratio** | 267-line clusterfile → 2,712 lines of production config |
| **32 K8s resources** | ACM ZTP template alone generates 32 resources of 16 types from one file |
| **11 platforms** | AWS, Azure, GCP, vSphere, OpenStack, IBM Cloud, Nutanix, Baremetal, KubeVirt, SNO, External |
| **6 deployment methods** | Agent-based, IPI, ACM ZTP, ACM CAPI, UPI, SiteConfig |
| **134 regression tests** | Every platform x method combination tested automatically |
| **6 operator plugins** | ArgoCD, LVM, ODF, ACM, cert-manager, External Secrets — smart defaults, ACM policy wrappers |
| **19 example clusterfiles** | Ready-to-use for every platform and topology |
| **Production validated** | Baremetal, KubeVirt, cloud IPI, disconnected, ACM-managed fleets |
| **Zero inline secrets** | All sensitive content externalized as file paths; safe to commit, review, and share |
| **Web editor** | Offline-first, no telemetry, schema-driven — accessible to anyone, runs anywhere |

---

## The Ask

1. **Try it** — Load a sample clusterfile in the editor, change the platform, render a template. See the 10x output in seconds.
2. **Adopt it** — Use clusterfiles on your next engagement instead of hand-crafted YAML. Measure the time savings.
3. **Contribute** — Add templates for new output formats, new operator plugins, new platform features.
4. **Evangelize** — Share with your team, your customers, your community. The gap is real and so is the solution.

---

*Clusterfile v3.4.0 — `quay.io/dds/clusterfile-editor:latest`*
