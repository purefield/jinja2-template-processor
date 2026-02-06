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
{%- set platformPlugin = plugins[platform] | default({}) if plugins is defined else {} -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}{% if platform not in ['baremetal', 'none'] %}
  platform:
{% include 'includes/platforms/' ~ platform ~ '/controlPlane.yaml.tpl' %}{%- endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}{% if platform not in ['baremetal', 'none'] %}
    platform:
{% include 'includes/platforms/' ~ platform ~ '/compute.yaml.tpl' %}{%- endif %}{% if network.proxy is defined %}

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
{% include 'includes/platforms/' ~ platform ~ '/platform.yaml.tpl' %}

publish: External
pullSecret: '{{ load_file(account.pullSecret) | trim }}'
sshKey: |{% for pubKey in cluster.sshKeys %}
  {{ load_file(pubKey) | trim }}{%- endfor %}{% if network.trustBundle is defined %}

additionalTrustBundle: |
{{ load_file(network.trustBundle) | indent(2, true) }}
{%- endif %}
{%- if cluster.mirrors is defined and cluster.mirrors | length > 0 %}

imageContentSources:{% for mirror in cluster.mirrors %}
  - source: {{ mirror.source }}
    mirrors:{% for m in mirror.mirrors %}
      - {{ m }}{%- endfor %}{%- endfor %}{%- endif %}{% if platformPlugin.credentials is defined %}

credentialsMode: Manual
{%- endif %}
{#- SNO bootstrap disk for platform: none #}
{%- if platform == 'none' and controlCount == 1 and (hosts.values()|first).storage is defined and (hosts.values()|first).storage.os is defined %}
{%- set bootstrapDisk = (hosts.values()|first).storage.os %}

bootstrapInPlace:
  installationDisk: {{ bootstrapDisk if bootstrapDisk is string else bootstrapDisk.deviceName }}
{%- endif %}
