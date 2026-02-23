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
{%- for op_name, op_config in ops.items() if op_config is mapping and op_config.enabled | default(true) %}{% include "operators/" ~ op_name ~ "/manifests.yaml.tpl" %}{% include "operators/" ~ op_name ~ "/config.yaml.tpl" ignore missing %}{% endfor -%}
