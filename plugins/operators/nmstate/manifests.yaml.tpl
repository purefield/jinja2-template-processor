{%- set nm = ((plugins | default({})).operators | default({})).get('nmstate', {}) -%}
{%- set nmEnabled = nm.enabled | default(cluster.platform in ["baremetal", "kubevirt"]) -%}
{%- if nmEnabled %}
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-nmstate
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-nmstate
  namespace: openshift-nmstate
spec:
  targetNamespaces:
    - openshift-nmstate
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kubernetes-nmstate-operator
  namespace: openshift-nmstate
spec:
  channel: {{ nm.channel | default("stable") }}
  installPlanApproval: {{ nm.approval | default("Automatic") }}
  name: kubernetes-nmstate-operator
  source: {{ nm.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace{% if nm.version %}
  startingCSV: {{ nm.version }}{% endif %}
---
apiVersion: nmstate.io/v1
kind: NMState
metadata:
  name: nmstate
{%- endif -%}
