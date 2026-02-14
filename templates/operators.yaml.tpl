{#- @meta
name: operators.yaml
description: Day-2 operator installation manifests (Subscriptions + CRs)
type: clusterfile
category: configuration
platforms:
  - baremetal
  - kubevirt
  - aws
  - azure
  - gcp
  - vsphere
  - openstack
  - ibmcloud
  - nutanix
  - none
requires:
  - plugins.operators
docs: https://docs.openshift.com/container-platform/latest/operators/admin/olm-adding-operators-to-cluster.html
-#}
{#- Standalone operator manifests for post-install: oc apply -f operators.yaml #}
{%- set ops = plugins.operators | default({}) if plugins is defined else {} -%}
{%- if ops.argocd is defined %}{% include "plugins/operators/argocd/manifests.yaml.tpl" %}{% endif -%}
