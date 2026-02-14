# cert-manager Operator

TLS certificate automation for OpenShift. This is an install-and-go operator — no custom resources are needed for the base installation. ClusterIssuer and Certificate resources are cluster-specific day-2 configuration.

## Quick start

```yaml
plugins:
  operators:
    cert-manager: {}    # All defaults: stable-v1 channel
```

## What gets installed

| Resource | Kind | Namespace |
|----------|------|-----------|
| `cert-manager-operator` | Namespace | — |
| `cert-manager-operator` | OperatorGroup | `cert-manager-operator` |
| `openshift-cert-manager-operator` | Subscription | `cert-manager-operator` |

## Configuration reference

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | bool | `true` | Set `false` to skip installation |
| `channel` | string | `stable-v1` | OLM subscription channel |
| `approval` | string | `Automatic` | InstallPlan approval: `Automatic` or `Manual` |
| `source` | string | `redhat-operators` | OLM CatalogSource name |

This operator has no additional configuration beyond the common operator fields. Once installed, configure ClusterIssuers and Certificates as day-2 operations specific to your cluster.

## Examples

### Minimal (all defaults)

```yaml
plugins:
  operators:
    cert-manager: {}
```

### Disconnected with manual approval

```yaml
plugins:
  operators:
    cert-manager:
      channel: stable-v1
      source: my-custom-catalog
      approval: Manual
```

## Render

```bash
# Standalone manifests
./process.py data/sno.clusterfile templates/operators.yaml.tpl

# As ABI extra manifests
./process.py data/sno.clusterfile templates/install-config.yaml.tpl

# As ACM Policy for managed clusters
./process.py data/baremetal.clusterfile templates/acm-ztp.yaml.tpl
```

## Template files

| File | Purpose |
|------|---------|
| `manifests.yaml.tpl` | Standalone YAML: Namespace, OperatorGroup, Subscription |
| `policy.yaml.tpl` | ACM Policy + ConfigurationPolicy + PlacementBinding |
