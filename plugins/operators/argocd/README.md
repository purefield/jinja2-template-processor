# ArgoCD / OpenShift GitOps Operator

Installs the OpenShift GitOps operator and configures an ArgoCD instance with RBAC, resource limits, and an optional bootstrap Application for app-of-apps patterns.

## Quick start

```yaml
plugins:
  operators:
    argocd: {}    # All defaults: latest channel, Automatic approval
```

## What gets installed

| Resource | Kind | Namespace |
|----------|------|-----------|
| `openshift-gitops-operator` | Namespace | — |
| `openshift-gitops-operator` | OperatorGroup | `openshift-gitops-operator` |
| `openshift-gitops-operator` | Subscription | `openshift-gitops-operator` |
| `openshift-gitops` | ArgoCD | `openshift-gitops` |
| `cluster-bootstrap` | Application | `openshift-gitops` (optional) |

## Configuration reference

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | bool | `true` | Set `false` to skip installation |
| `channel` | string | `latest` | OLM subscription channel (e.g. `latest`, `gitops-1.14`) |
| `approval` | string | `Automatic` | InstallPlan approval: `Automatic` or `Manual` |
| `source` | string | `redhat-operators` | OLM CatalogSource name |
| `ha` | bool | `false` | Enable HA for ArgoCD components |
| `notifications` | bool | `true` | Set `false` to disable notifications controller |
| `applicationSet` | bool | `true` | Enable ApplicationSet controller |

### RBAC

```yaml
plugins:
  operators:
    argocd:
      rbac:
        policy: "g, system:cluster-admins, role:admin"
        defaultPolicy: "role:readonly"
        scopes: "[groups]"
```

| Property | Default | Description |
|----------|---------|-------------|
| `rbac.policy` | `g, system:cluster-admins, role:admin` | ArgoCD RBAC policy CSV |
| `rbac.defaultPolicy` | `role:readonly` | Default role for authenticated users |
| `rbac.scopes` | `[groups]` | OIDC scopes to use for RBAC |

### Repo server resources

```yaml
plugins:
  operators:
    argocd:
      repo:
        resources:
          cpu: "2"
          memory: 2Gi
```

| Property | Default | Description |
|----------|---------|-------------|
| `repo.resources.cpu` | `1` | CPU limit for repo server |
| `repo.resources.memory` | `1Gi` | Memory limit for repo server |

### Bootstrap Application (app-of-apps)

Configure a bootstrap Application that manages further operators and configuration from a Git repository:

```yaml
plugins:
  operators:
    argocd:
      bootstrap:
        repoURL: https://gitea.example.com/org/cluster-config.git
        path: operators
        targetRevision: HEAD
        namespace: openshift-gitops
        autoSync: true
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `bootstrap.repoURL` | string | *required* | Git repository URL |
| `bootstrap.path` | string | `.` | Path within the repo |
| `bootstrap.targetRevision` | string | `HEAD` | Git ref (branch, tag, commit) |
| `bootstrap.namespace` | string | `openshift-gitops` | Destination namespace |
| `bootstrap.autoSync` | bool | `true` | Enable automated sync with prune and self-heal |

## Examples

### Minimal (all defaults)

```yaml
plugins:
  operators:
    argocd: {}
```

### HA with bootstrap

```yaml
plugins:
  operators:
    argocd:
      ha: true
      bootstrap:
        repoURL: https://github.com/org/cluster-config.git
        path: operators
```

### Disconnected with custom catalog

```yaml
plugins:
  operators:
    argocd:
      channel: gitops-1.14
      source: my-custom-catalog
      approval: Manual
```

## Render

```bash
# Standalone manifests
./process.py data/sno.clusterfile templates/operators.yaml.tpl

# As ABI extra manifests (embedded in install-config)
./process.py data/sno.clusterfile templates/install-config.yaml.tpl

# As ACM Policy for managed clusters (ZTP)
./process.py data/baremetal.clusterfile templates/acm-ztp.yaml.tpl
```

## Template files

| File | Purpose |
|------|---------|
| `manifests.yaml.tpl` | Standalone YAML for `oc apply` or ABI extra manifests |
| `policy.yaml.tpl` | ACM Policy + ConfigurationPolicy + PlacementBinding for ZTP/CAPI |
