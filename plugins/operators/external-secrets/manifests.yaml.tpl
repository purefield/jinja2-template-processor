{%- set es = plugins.operators['external-secrets'] -%}
{%- set esEnabled = es.enabled | default(true) -%}
{%- if esEnabled %}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: external-secrets-operator
  namespace: openshift-operators
spec:
  channel: {{ es.channel | default("stable-v1") }}
  installPlanApproval: {{ es.approval | default("Automatic") }}
  name: external-secrets-operator
  source: {{ es.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace
{%- endif -%}
