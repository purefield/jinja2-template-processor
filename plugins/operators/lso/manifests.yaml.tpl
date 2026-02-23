{%- set lso = plugins.operators.lso -%}
{%- set lsoEnabled = lso.enabled | default(true) -%}
{%- set dis = lso.deviceInclusionSpec | default({}) -%}
{%- set ns = lso.nodeSelector | default({"cluster.ocs.openshift.io/openshift-storage": ""}) -%}
{%- if lsoEnabled %}
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-local-storage
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-storage-operatorgroup
  namespace: openshift-local-storage
spec:
  targetNamespaces:
    - openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: {{ lso.channel | default("stable") }}
  installPlanApproval: {{ lso.approval | default("Automatic") }}
  name: local-storage-operator
  source: {{ lso.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace
---
apiVersion: local.openshift.io/v1alpha1
kind: LocalVolumeSet
metadata:
  name: local-block
  namespace: openshift-local-storage
spec:
  storageClassName: {{ lso.storageClassName | default("local-block") }}
  volumeMode: {{ lso.volumeMode | default("Block") }}{% if lso.volumeMode | default("Block") == "Filesystem" %}
  fsType: {{ lso.fsType | default("xfs") }}{% endif %}
  nodeSelector:
    nodeSelectorTerms:
      - matchExpressions:{% for key, val in ns.items() %}
          - key: {{ key }}
            operator: In
            values:
              - "{{ val }}"{% endfor %}
  deviceInclusionSpec:
    deviceTypes:{% for dt in dis.deviceTypes | default(["disk"]) %}
      - {{ dt }}{% endfor %}{% if dis.minSize is defined %}
    minSize: {{ dis.minSize }}{% endif %}{% if dis.maxSize is defined %}
    maxSize: {{ dis.maxSize }}{% endif %}
{%- endif -%}
