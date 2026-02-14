{%- set acm = plugins.operators.acm -%}
{%- set acmEnabled = acm.enabled | default(true) -%}
{%- set mch = acm.multiClusterHub | default({}) -%}
{%- set asc = acm.agentServiceConfig | default({}) -%}
{%- set prov = acm.provisioning | default({}) -%}
{%- if acmEnabled %}
---
apiVersion: v1
kind: Namespace
metadata:
  name: open-cluster-management
  annotations:
    openshift.io/display-name: "Advanced Cluster Management for Kubernetes"
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: advanced-cluster-management-group
  namespace: open-cluster-management
spec:
  targetNamespaces:
    - open-cluster-management
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: acm-operator-subscription
  namespace: open-cluster-management
spec:
  channel: {{ acm.channel | default("release-2.14") }}
  installPlanApproval: {{ acm.approval | default("Automatic") }}
  name: advanced-cluster-management
  source: {{ acm.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace
---
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: {{ mch.name | default("multiclusterhub") }}
  namespace: open-cluster-management
spec:
  availabilityConfig: {{ mch.availabilityConfig | default("High") }}
---
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
  name: agent
spec:
  databaseStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: {{ asc.databaseStorage | default("10Gi") }}
  filesystemStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: {{ asc.filesystemStorage | default("100Gi") }}
  imageStorage:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: {{ asc.imageStorage | default("50Gi") }}
---
apiVersion: metal3.io/v1alpha1
kind: Provisioning
metadata:
  name: provisioning-configuration
spec:
  provisioningNetwork: "Disabled"
  watchAllNamespaces: {{ prov.watchAllNamespaces | default(true) | lower }}
{%- endif -%}
