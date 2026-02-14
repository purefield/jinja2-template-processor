# External Secrets Operator

Syncs secrets from external stores (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, etc.) into Kubernetes Secrets. Runs in all-namespaces mode via `openshift-operators` — no dedicated namespace or OperatorGroup needed.

## Quick start

```yaml
plugins:
  operators:
    external-secrets: {}    # All defaults: stable-v1 channel, global scope
```

## What gets installed

| Resource | Kind | Namespace |
|----------|------|-----------|
| `external-secrets-operator` | Subscription | `openshift-operators` |

The operator runs in global scope (`openshift-operators` namespace) and watches all namespaces for ExternalSecret resources. No OperatorGroup is needed because `openshift-operators` already has a global OperatorGroup.

## Configuration reference

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | bool | `true` | Set `false` to skip installation |
| `channel` | string | `stable-v1` | OLM subscription channel |
| `approval` | string | `Automatic` | InstallPlan approval: `Automatic` or `Manual` |
| `source` | string | `redhat-operators` | OLM CatalogSource name |

This operator has no additional configuration beyond the common operator fields. Once installed, create SecretStore/ClusterSecretStore and ExternalSecret resources to sync secrets from your external provider.

## Examples

### Minimal (all defaults)

```yaml
plugins:
  operators:
    external-secrets: {}
```

### Disconnected with manual approval

```yaml
plugins:
  operators:
    external-secrets:
      channel: stable-v1
      source: my-custom-catalog
      approval: Manual
```

### Typical usage with Vault

After the operator is installed, create a ClusterSecretStore and ExternalSecret (day-2 config, not part of this plugin):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault
spec:
  provider:
    vault:
      server: https://vault.example.com
      path: secret
      auth:
        kubernetes:
          mountPath: kubernetes
          role: external-secrets
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: my-secret
  data:
    - secretKey: password
      remoteRef:
        key: secret/data/my-app
        property: password
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
| `manifests.yaml.tpl` | Standalone YAML: Subscription (global scope in `openshift-operators`) |
| `policy.yaml.tpl` | ACM Policy + ConfigurationPolicy + PlacementBinding |
