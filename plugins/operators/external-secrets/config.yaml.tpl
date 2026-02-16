{%- set es = plugins.operators['external-secrets'] -%}
{%- set v = es.vault -%}
{%- set vServer = v.server | default("http://vault-openbao.vault.svc.cluster.local:8200") -%}
{%- set vPath = v.path | default("secret") -%}
{%- set vRole = v.role | default("external-secrets") -%}
{%- set vName = v.name | default("vault") -%}
{%- set vSA = v.serviceAccount | default("external-secrets") -%}
{%- set vSANS = v.serviceAccountNamespace | default("openshift-operators") %}
---
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: {{ vName }}
spec:
  provider:
    vault:
      server: {{ vServer }}
      path: {{ vPath }}
      version: v2
      auth:
        kubernetes:
          mountPath: kubernetes
          role: {{ vRole }}
          serviceAccountRef:
            name: {{ vSA }}
            namespace: {{ vSANS }}
