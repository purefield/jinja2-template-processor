{#- @meta
name: kubevirt-cleanup.sh
description: Cleanup script for KubeVirt VMs, PVCs, CUDN, and namespace
type: clusterfile
category: kubevirt
platforms:
  - kubevirt
requires:
  - cluster.name
relatedTemplates:
  - kubevirt-cluster.yaml.tpl
docs: https://docs.openshift.com/container-platform/4.20/virt/about_virt/about-virt.html
-#}
{%- set kv = plugins.kubevirt | default({}) -%}
{%- set netType = kv.networkType | default("cudn") -%}
{%- set netName = cluster.name + "-vmnet" if netType == "cudn" else "virtualmachine-net" -%}
{%- set namespace = cluster.name + "-cluster" -%}
#!/bin/bash
# Cleanup script for KubeVirt cluster: {{ cluster.name }}
# Deletes VMs, PVCs, networking, and namespace
set -euo pipefail

NAMESPACE="{{ namespace }}"

echo "Stopping VMs in $NAMESPACE"
oc get vm -n "$NAMESPACE" -o name 2>/dev/null | xargs -r oc delete -n "$NAMESPACE" --wait=true || true

echo "Deleting PVCs in $NAMESPACE"
oc delete pvc --all -n "$NAMESPACE" --wait=true || true
{% if netType == "cudn" %}
echo "Deleting ClusterUserDefinedNetwork {{ netName }}"
oc delete clusteruserdefinednetwork {{ netName }} --wait=true || true
{% else %}
echo "Deleting NetworkAttachmentDefinition {{ netName }}"
oc delete net-attach-def {{ netName }} -n "$NAMESPACE" || true
{% endif %}
echo "Deleting namespace $NAMESPACE"
oc delete namespace "$NAMESPACE" --wait=true || true

echo "Cleanup complete for {{ cluster.name }}"
