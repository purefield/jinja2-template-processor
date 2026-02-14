{#- @meta
name: install-config.yaml
description: OpenShift installer configuration for IPI and agent-based installs
type: clusterfile
category: installation
platforms:
  - aws
  - azure
  - gcp
  - vsphere
  - openstack
  - ibmcloud
  - nutanix
  - baremetal
  - kubevirt
  - none
requires:
  - account.pullSecret
  - cluster.name
  - cluster.sshKeys
  - network.domain
  - network.primary.subnet
  - network.cluster.subnet
  - network.service.subnet
  - hosts
relatedTemplates:
  - agent-config.yaml.tpl
  - creds.yaml.tpl
  - mirror-registry-config.yaml.tpl
  - pre-check.sh.tpl
docs: https://docs.openshift.com/container-platform/latest/installing/index.html
-#}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set platform = cluster.platform | default('baremetal', true) -%}
{%- set insecureMirrors = cluster.mirrors | default([]) | selectattr('insecure', 'defined') | selectattr('insecure') | list -%}
{%- set platformPlugin = plugins[platform] | default({}) if plugins is defined else {} -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}{% if cluster.cpuPartitioningMode is defined and cluster.cpuPartitioningMode != "None" %}

cpuPartitioningMode: {{ cluster.cpuPartitioningMode }}{% endif %}

controlPlane:
  name: master
  replicas: {{ controlCount }}{% if platform not in ['baremetal', 'kubevirt', 'none', 'external'] %}
  platform:
{% include 'plugins/platforms/' ~ platform ~ '/controlPlane.yaml.tpl' %}{%- endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}{% if platform not in ['baremetal', 'kubevirt', 'none', 'external'] %}
    platform:
{% include 'plugins/platforms/' ~ platform ~ '/compute.yaml.tpl' %}{%- endif %}{% if network.proxy is defined %}

proxy:
  httpProxy: {{ network.proxy.httpProxy }}
  httpsProxy: {{ network.proxy.httpsProxy }}
  noProxy: {{ network.proxy.noProxy }}
{%- endif %}

networking:
  networkType: {{ network.primary.type | default("OVNKubernetes", true) }}
  clusterNetwork:
    - cidr: {{ network.cluster.subnet }}
      hostPrefix: {{ network.cluster.hostPrefix | default(23, true) }}
  machineNetwork:
    - cidr: {{ network.primary.subnet }}
  serviceNetwork:
    - {{ network.service.subnet }}

platform:
{% include 'plugins/platforms/' ~ platform ~ '/platform.yaml.tpl' %}

publish: External
pullSecret: '{{ load_file(account.pullSecret) | trim }}'
sshKey: |{% for pubKey in cluster.sshKeys %}
  {{ load_file(pubKey) | trim }}{%- endfor %}{% if network.trustBundle is defined %}

additionalTrustBundle: |
{{ load_file(network.trustBundle) | indent(2, true) }}
{%- endif %}
{%- if cluster.mirrors is defined and cluster.mirrors | length > 0 %}

imageDigestSources:{% for mirror in cluster.mirrors %}
  - source: {{ mirror.source }}
    mirrors:{% for m in mirror.mirrors %}
      - {{ m }}{%- endfor %}{%- endfor %}{%- endif %}{% if platformPlugin.credentials is defined %}

credentialsMode: Manual
{%- endif %}
{#- SNO bootstrap disk for platform: none or kubevirt SNO #}
{%- if platform in ['none', 'kubevirt'] and controlCount == 1 and (hosts.values()|first).storage is defined and (hosts.values()|first).storage.os is defined %}
{%- set bootstrapDisk = (hosts.values()|first).storage.os %}

bootstrapInPlace:
  installationDisk: {{ bootstrapDisk if bootstrapDisk is string else bootstrapDisk.deviceName }}
{%- endif %}{% if cluster.disconnected | default(false) %}
---
# Place in openshift/ directory for ABI/IPI
apiVersion: config.openshift.io/v1
kind: OperatorHub
metadata:
  name: cluster
spec:
  disableAllDefaultSources: true{% endif %}{% if cluster.catalogSources is defined %}{% for catalog in cluster.catalogSources %}
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: {{ catalog.name }}
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: {{ catalog.image }}
  displayName: {{ catalog.displayName | default(catalog.name) }}
  publisher: {{ catalog.publisher | default("Custom") }}{% endfor %}{% endif %}{% if insecureMirrors %}
---
# Place in openshift/ directory for ABI/IPI
apiVersion: config.openshift.io/v1
kind: Image
metadata:
  name: cluster
spec:
  registrySources:
    insecureRegistries:{% for mirror in insecureMirrors %}{% for location in mirror.mirrors %}
      - {{ location }}{% endfor %}{% endfor %}{% endif %}{% if plugins is defined and plugins.operators is defined %}
{%- set ops = plugins.operators -%}
{%- if ops.argocd is defined %}{%- set operatorManifests %}{% include "operators/argocd/manifests.yaml.tpl" %}{% endset %}
{{ operatorManifests }}{% endif -%}
{%- if ops.lvm is defined %}{%- set operatorManifests %}{% include "operators/lvm/manifests.yaml.tpl" %}{% endset %}
{{ operatorManifests }}{% endif -%}
{%- if ops.odf is defined %}{%- set operatorManifests %}{% include "operators/odf/manifests.yaml.tpl" %}{% endset %}
{{ operatorManifests }}{% endif -%}
{%- if ops.acm is defined %}{%- set operatorManifests %}{% include "operators/acm/manifests.yaml.tpl" %}{% endset %}
{{ operatorManifests }}{% endif -%}
{%- if ops['cert-manager'] is defined %}{%- set operatorManifests %}{% include "operators/cert-manager/manifests.yaml.tpl" %}{% endset %}
{{ operatorManifests }}{% endif -%}
{%- if ops['external-secrets'] is defined %}{%- set operatorManifests %}{% include "operators/external-secrets/manifests.yaml.tpl" %}{% endset %}
{{ operatorManifests }}{% endif -%}
{% endif %}
