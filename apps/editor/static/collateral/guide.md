# Getting Started with Clusterfile

A clusterfile is a single YAML file that describes everything about an OpenShift cluster — nodes, networking, credentials, and install method. You fill in the placeholders, pick a template, and the tool generates deployment-ready manifests.

---

## Coming from VMware?

This tool deploys OpenShift onto **bare-metal** (or virtual) servers — not onto vSphere. The servers you're targeting are physical machines you boot via BMC (iDRAC on Dell, iLO on HP/HPE, IPMI on others). VMware is your background, not your target platform.

| What you know (VMware) | What this tool does |
|---|---|
| ESXi host | Your physical server |
| vCenter | ACM hub cluster |
| Deploy OVA / mount ISO | Boot server via BMC virtual media (Redfish) |
| VM power on | BMC triggers PXE or ISO boot |
| Guest OS provisioning | Ignition config delivered by agent-based installer |
| vCenter task list | `oc get clusterdeployment` on the ACM hub |

The output of this tool is applied to an ACM hub cluster with `oc apply`, or used directly with `openshift-install`. ACM then powers the target servers on via Redfish/BMC virtual media and provisions OpenShift over the network.

---

## Recommended directory layout

Clone the repo and create your clusters directory as siblings. Work from `my-clusters/`.

```
./
├── clusterfile/                     ← repo clone (templates, processor)
└── my-clusters/                     ← your working directory
    └── my-cluster/
        ├── my-cluster.clusterfile   ← single source of truth
        ├── secrets/
        │   ├── pull-secret.json     ← Red Hat pull secret
        │   ├── id_rsa.pub           ← SSH public key
        │   └── bmc-password.txt     ← BMC / iDRAC password
        └── manifests/               ← generated output (commit, never secrets/)
```

---

## Step 1 — Set up the repo

Clone the repo once. All clusters share the same templates.

```bash
git clone https://github.com/dds/clusterfile
mkdir -p my-clusters/my-cluster/secrets
cd my-clusters
```

From this point all commands run from `my-clusters/`.

---

## Step 2 — Create a clusterfile

Pick the starter that matches your topology:

<a href="#" class="guide-action-btn" data-action="new-document">Open New Document Wizard ↗</a>

Or from the CLI:

```bash
# Single node (SNO)
cp ../clusterfile/data/start-sno.clusterfile my-cluster/my-cluster.clusterfile

# Compact (3 control nodes, no workers)
cp ../clusterfile/data/start-compact.clusterfile my-cluster/my-cluster.clusterfile

# Full HA (3 control + workers)
cp ../clusterfile/data/start-full.clusterfile my-cluster/my-cluster.clusterfile
```

---

## Step 3 — Add your secrets

```bash
# SSH public key
cp ~/.ssh/id_rsa.pub my-cluster/secrets/

# Pull secret — download from console.redhat.com → OpenShift → Downloads
cp ~/Downloads/pull-secret.json my-cluster/secrets/

# BMC password (one per host, or share if identical)
echo 'your-bmc-password' > my-cluster/secrets/bmc-password.txt

chmod 600 my-cluster/secrets/*
```

---

## Step 4 — Fill in the placeholders

Every `<placeholder>` value must be replaced before rendering. Use the **Todo** panel to see what's missing:

<a href="#" class="guide-action-btn" data-action="goto-todo">Open Todo ↗</a>

Use **Validation** to catch schema errors:

<a href="#" class="guide-action-btn" data-action="goto-validation">Open Validation ↗</a>

---

## Step 5 — Pick an install method

Use the **Templates** section to choose and preview the install method:

<a href="#" class="guide-action-btn" data-action="goto-templates">Open Templates ↗</a>

| Template | Method | When to use |
|---|---|---|
| `install-config.yaml` | Agent-based / IPI | Direct OCP install on bare metal |
| `agent-config.yaml` | Agent-based | Companion to install-config |
| `acm-ztp.yaml` | ACM ZTP | Hub cluster manages install via ACM |
| `acm-capi-m3.yaml` | CAPI + Metal3 | ACM with Cluster API provisioning |
| `nodes-config.yaml` | NMState only | Network config snippet for existing installs |
| `operators.yaml` | Day 2 | Operators and post-install config |

---

## Step 6 — Render and apply

```bash
# Render to stdout
python3 ../clusterfile/process.py \
  my-cluster/my-cluster.clusterfile \
  ../clusterfile/templates/acm-ztp.yaml.tpl

# Render to file
python3 ../clusterfile/process.py \
  my-cluster/my-cluster.clusterfile \
  ../clusterfile/templates/acm-ztp.yaml.tpl \
  > my-cluster/manifests/acm-ztp.yaml

# Apply directly to a cluster
python3 ../clusterfile/process.py \
  my-cluster/my-cluster.clusterfile \
  ../clusterfile/templates/acm-ztp.yaml.tpl \
  | oc apply -f -
```

Or use the **Download** button in the editor header to save the rendered manifest from the browser.

---

## Running the editor locally

```bash
# Using the container image (simplest)
podman run -d -p 8000:8000 --name clusterfile-editor \
  quay.io/dds/clusterfile-editor:latest

# From source
cd ../clusterfile
pip install -r requirements.txt
uvicorn apps.editor.app.main:app --reload --port 8000
```

Open [http://localhost:8000](http://localhost:8000) in your browser.
