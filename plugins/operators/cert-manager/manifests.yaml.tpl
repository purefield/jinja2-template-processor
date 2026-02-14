{%- set cm = plugins.operators['cert-manager'] -%}
{%- set cmEnabled = cm.enabled | default(true) -%}
{%- if cmEnabled %}
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator
  namespace: cert-manager-operator
spec:
  targetNamespaces:
    - cert-manager-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: cert-manager-operator
spec:
  channel: {{ cm.channel | default("stable-v1") }}
  installPlanApproval: {{ cm.approval | default("Automatic") }}
  name: openshift-cert-manager-operator
  source: {{ cm.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace
{%- endif -%}
