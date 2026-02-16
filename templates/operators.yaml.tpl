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
{%- if ops.argocd is defined %}{% include "operators/argocd/manifests.yaml.tpl" %}{% endif -%}
{%- if ops.lvm is defined %}{% include "operators/lvm/manifests.yaml.tpl" %}{% endif -%}
{%- if ops.odf is defined %}{% include "operators/odf/manifests.yaml.tpl" %}{% endif -%}
{%- if ops.acm is defined %}{% include "operators/acm/manifests.yaml.tpl" %}{% endif -%}
{%- if ops['cert-manager'] is defined %}{% include "operators/cert-manager/manifests.yaml.tpl" %}{% endif -%}
{%- if ops['cert-manager'] is defined and ops['cert-manager'].letsencrypt is defined %}{% include "operators/cert-manager/config.yaml.tpl" %}{% endif -%}
{%- if ops['external-secrets'] is defined %}{% include "operators/external-secrets/manifests.yaml.tpl" %}{% endif -%}
{%- if ops['external-secrets'] is defined and ops['external-secrets'].vault is defined %}{% include "operators/external-secrets/config.yaml.tpl" %}{% endif -%}
