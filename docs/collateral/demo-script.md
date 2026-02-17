# Clusterfile Live Demo Script

*5-minute walkthrough — web editor with live rendering*

---

## Setup (before the demo)

1. Ensure the editor is running:
   ```
   podman run -d -p 8000:8000 --name clusterfile-editor quay.io/dds/clusterfile-editor:latest
   ```
2. Open `http://localhost:8000` in a browser
3. Have a terminal ready for the CLI step (step 7)
4. Pre-load the baremetal sample so the editor is not empty when you start

---

## Step 1: Open the Editor and Load a Sample (30 seconds)

**Action:** Click "Load" → select `baremetal.clusterfile` from the samples list.

**Talking points:**
- "This is a complete baremetal cluster definition — three control-plane nodes, networking, BMC credentials, storage, everything in one file."
- "Notice the pull secret and SSH keys are file paths, not inline blobs. Same for BMC passwords, CA certificates, cloud credentials. The clusterfile references external files — the processor reads them at render time. This keeps the YAML compact and secrets out of version control."
- "The left pane is a schema-driven form — every field is validated against a JSON Schema. The right pane is the raw YAML."
- "Notice the form sections: Account, Cluster, Network, Hosts, Plugins. This is the full anatomy of a cluster."

**What the audience sees:** A populated form with cluster name, network config, three hosts with BMC details. File-path fields show a file icon.

---

## Step 2: Change Platform — Baremetal to KubeVirt (45 seconds)

**Action:** In the Cluster section, change `platform` from `baremetal` to `kubevirt`.

**Talking points:**
- "Watch what happens when I change the platform — the schema adapts. Baremetal-specific fields like BMC credentials disappear. KubeVirt-specific fields like storage class appear."
- "The cluster intent stays the same: three nodes, this network, these operators. Only the platform-specific details change."
- "This is the core insight — same data, different output format."

**What the audience sees:** Form fields update dynamically. BMC section disappears. KubeVirt plugin section appears with storage class options.

---

## Step 3: Enable Operators — cert-manager + external-secrets (30 seconds)

**Action:** Scroll to Plugins → Operators. Enable `cert-manager` and `external-secrets` (toggle to enabled). Show the default configuration that appears.

**Talking points:**
- "Operators are plugins. Enable them with a toggle, and smart defaults fill in the rest — channel, catalog source, approval strategy."
- "These are day-2 operators that get deployed to the cluster after it's running. The clusterfile just describes what you want installed — the templates generate the OLM Subscriptions and config CRs."
- "external-secrets generates a Vault ClusterSecretStore — that runs on the cluster itself to sync secrets from Vault into Kubernetes Secrets. It's not part of the rendering process."
- "cert-manager gets LetsEncrypt DNS-01 via Route53 — and it uses an ExternalSecret to pull the AWS credentials from Vault at runtime."

**What the audience sees:** Operator toggles flip to enabled. Default config fields appear with sensible values pre-filled.

---

## Step 4: Render install-config (45 seconds)

**Action:** Click the template dropdown → select `install-config.yaml.tpl` → click "Render".

**Talking points:**
- "This is the output the OpenShift installer expects. Platform section, networking, control plane — all generated from the clusterfile."
- "Notice it picked up the KubeVirt platform automatically. If I switch back to baremetal, the platform section changes but the cluster identity and network stay the same."
- "One source file, rendered to the exact format each tool expects."

**What the audience sees:** Rendered `install-config.yaml` in the output pane with syntax highlighting. Platform section shows KubeVirt-specific config.

---

## Step 5: Render operators.yaml — Subscriptions + ClusterSecretStore (45 seconds)

**Action:** Switch template to `operators.yaml.tpl` → click "Render".

**Talking points:**
- "Same clusterfile, different output. Now we get OLM Subscriptions for cert-manager and external-secrets, plus a ClusterSecretStore CR pointing to Vault."
- "This is the day-2 config — manifests you apply after the cluster is up. These operators run on the created cluster, not during rendering."
- "The ESO ClusterSecretStore tells the cluster where its Vault is and how to authenticate. Once applied, ESO syncs secrets from Vault into Kubernetes Secrets automatically."
- "No more maintaining a separate operators manifest. Change the Vault URL in the clusterfile, and every output that references it updates."

**What the audience sees:** YAML output with Namespace, OperatorGroup, Subscription resources for each enabled operator, plus a ClusterSecretStore CR.

---

## Step 6: Render SiteConfig — ClusterInstance CR (45 seconds)

**Action:** Switch template to `clusterfile2siteconfig.yaml.tpl` → click "Render".

**Talking points:**
- "For teams using the ACM SiteConfig operator, the same clusterfile renders a ClusterInstance CR."
- "This is bidirectional — we also have a template that converts an existing ClusterInstance back to a clusterfile. So you can onboard existing SiteConfig workflows."
- "Same data, six output formats. That's the value of a single source of truth."

**What the audience sees:** A ClusterInstance CR with cluster config, node definitions, and network config mapped from the clusterfile.

---

## Step 7: CLI Render — Pipe to oc apply (45 seconds)

**Action:** Switch to terminal. Run:
```bash
python process.py -t operators.yaml.tpl -d data/baremetal.clusterfile
```

**Talking points:**
- "Everything you saw in the editor also works from the command line. One command, one template, one clusterfile."
- "In a CI/CD pipeline, this becomes: `python process.py -t operators.yaml.tpl -d cluster.yaml | oc apply -f -`"
- "Version the clusterfile in Git. Render in CI. Apply with ArgoCD. Full GitOps."
- "The processor is 400 lines of Python. No framework, no dependencies beyond Jinja2 and PyYAML. It runs anywhere."

**What the audience sees:** YAML output printed to terminal — same content as the editor rendered.

---

## Wrap-Up (15 seconds)

**Talking points:**
- "One YAML file. 102 templates. 11 platforms. 6 deployment methods. 134 tests."
- "Define your cluster once. Render it for any tool. Validate before you deploy."
- "The editor runs offline, in a container, with no telemetry. Your cluster data stays yours."

---

## Backup Demos (if time permits or questions arise)

### Pre-flight checks
```bash
python process.py -t pre-check.sh.tpl -d data/baremetal.clusterfile | bash
```
"Run DNS, NTP, BMC, and network validation before you even start the install."

### Disconnected/air-gapped
Load `acm-hub-sno.clusterfile` — show mirror registries, custom catalog sources, disconnected mode toggle.

### ACM ZTP
Render `acm-ztp.yaml.tpl` from `baremetal.clusterfile` — show InfraEnv, ClusterDeployment, BareMetalHost, NMState, AgentClusterInstall all generated from one file.

### Cluster overview
Render `cluster-overview.html.tpl` — show the HTML diagram of the cluster topology.

---

## Common Questions and Answers

**Q: How is this different from Helm?**
A: Helm charts are per-application. Clusterfile is per-cluster — one file generates outputs for multiple tools (installer, ACM, operators, scripts). Helm can't render an install-config and an ACM policy from the same values file.

**Q: Does it work disconnected?**
A: Yes. The editor is offline-first (no external calls). The clusterfile schema supports mirror registries, custom catalog sources, and disconnected mode.

**Q: Where do secrets live?**
A: Build-time secrets (pull secrets, SSH keys, BMC passwords, cloud credentials, CA certs) are files on disk — the clusterfile stores only the path. Runtime secrets on the created cluster are managed by ESO syncing from Vault. The clusterfile itself contains no secret values.

**Q: Can I use it with existing clusters?**
A: Yes. The `siteconfig2clusterfile.yaml.tpl` template converts existing ClusterInstance CRs to clusterfiles. You can also manually create a clusterfile from existing configs.

**Q: What about GitOps?**
A: Clusterfiles are YAML — they version cleanly in Git. The CLI renders deterministic output. ArgoCD integration is on the roadmap for automated rendering and application.
