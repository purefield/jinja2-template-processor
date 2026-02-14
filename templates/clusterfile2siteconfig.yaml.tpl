{#- @meta
name: clusterfile2siteconfig.yaml
description: Convert clusterfile to SiteConfig ClusterInstance CR
type: clusterfile
category: acm
platforms:
  - baremetal
  - none
requires:
  - account.pullSecret
  - cluster.name
  - cluster.sshKeys
  - network.domain
  - hosts
relatedTemplates:
  - siteconfig2clusterfile.yaml.tpl
  - acm-ztp.yaml.tpl
docs: https://github.com/stolostron/siteconfig
-#}
{%- set controlCount = hosts.values() | selectattr('role', 'equalto', 'control') | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker')  | list | length -%}
{%- set imageArch = cluster.arch | default("x86_64", true) -%}
{%- set clusterType = cluster.clusterType | default("SNO" if controlCount == 1 else "HighlyAvailable") -%}
{%- set platformType = cluster.platform | default("BareMetal" if controlCount > 1 else "None", true) -%}
{%- set platformMap = {"baremetal": "BareMetal", "none": "None", "vsphere": "VSphere", "aws": "AWS", "azure": "Azure", "gcp": "GCP", "external": "External"} -%}
{%- set platformType = platformMap[platformType] | default(platformType) if platformType in platformMap else platformType -%}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ cluster.name }}
---
apiVersion: v1
kind: Secret
metadata:
  name: pullsecret-{{ cluster.name }}
  namespace: {{ cluster.name }}
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{{ load_file(account.pullSecret) }}'{% for name, host in hosts.items() %}{% if host.bmc is defined %}
---
apiVersion: v1
kind: Secret
metadata:
  name: bmc-secret-{{ name }}
  namespace: {{ cluster.name }}
type: Opaque
stringData:
  username: '{{ host.bmc.username }}'
  password: '{{ load_file(host.bmc.password) }}'{% endif %}{% endfor %}
---
apiVersion: siteconfig.open-cluster-management.io/v1alpha1
kind: ClusterInstance
metadata:
  name: {{ cluster.name }}
  namespace: {{ cluster.name }}
spec:
  clusterName: {{ cluster.name }}
  baseDomain: {{ network.domain }}
  clusterImageSetNameRef: img{{ cluster.version }}-{{ imageArch | replace("_", "-") }}-appsub
  clusterType: {{ clusterType }}
  sshPublicKey: '{{ load_file(cluster.sshKeys | first) | trim }}'
  pullSecretRef:
    name: pullsecret-{{ cluster.name }}
  platformType: {{ platformType }}{% if cluster.holdInstallation | default(false) %}
  holdInstallation: true{% endif %}{% if cluster.cpuPartitioningMode is defined and cluster.cpuPartitioningMode != "None" %}
  cpuPartitioningMode: {{ cluster.cpuPartitioningMode }}{% endif %}
  cpuArchitecture: {{ imageArch }}{% if network.primary.subnet is defined %}
  machineNetwork:
    - cidr: {{ network.primary.subnet }}{% endif %}{% if network.cluster.subnet is defined %}
  clusterNetwork:
    - cidr: {{ network.cluster.subnet }}
      hostPrefix: {{ network.cluster.hostPrefix | default(23) }}{% endif %}{% if network.service.subnet is defined %}
  serviceNetwork:
    - {{ network.service.subnet }}{% endif %}{% if controlCount > 1 and network.primary.vips is defined %}
  apiVIPs:{% if network.primary.vips.api is string %}
    - {{ network.primary.vips.api }}{% else %}{% for vip in network.primary.vips.api %}
    - {{ vip }}{% endfor %}{% endif %}
  ingressVIPs:{% if network.primary.vips.apps is string %}
    - {{ network.primary.vips.apps }}{% else %}{% for vip in network.primary.vips.apps %}
    - {{ vip }}{% endfor %}{% endif %}{% endif %}{% if network.proxy is defined %}
  proxy:
    httpProxy: {{ network.proxy.httpProxy }}
    httpsProxy: {{ network.proxy.httpsProxy }}{% if network.proxy.noProxy is defined %}
    noProxy: {{ network.proxy.noProxy }}{% endif %}{% endif %}{% if network.ntpservers is defined %}
  additionalNTPSources:{% for ntp in network.ntpservers %}
    - {{ ntp }}{% endfor %}{% endif %}{% if cluster.tpm | default(false) or (cluster.diskEncryption is defined and cluster.diskEncryption.type | default("none") != "none") %}
  diskEncryption:{% if cluster.diskEncryption is defined and cluster.diskEncryption.type == "tang" %}
    type: tang
    tang:{% for server in cluster.diskEncryption.tang %}
      - url: {{ server.url }}
        thumbprint: {{ server.thumbprint }}{% endfor %}{% else %}
    type: tpm2{% endif %}{% endif %}
  nodes:{% for name, host in hosts.items() %}
    - hostName: {{ name }}
      role: {{ 'master' if host.role == 'control' else host.role }}{% if host.bmc is defined %}
      bmcAddress: {% if host.bmc.vendor == 'dell' %}{{ 'redfish' if host.bmc.version | default(9) >= 9 else 'idrac' }}-virtualmedia://{{ host.bmc.address }}/redfish/v1/Systems/System.Embedded.1{% elif host.bmc.vendor == 'hp' %}redfish-virtualmedia+https://{{ host.bmc.address }}/redfish/v1/Systems/1{% elif host.bmc.vendor == 'ksushy' %}redfish-virtualmedia://{{ host.bmc.address }}/redfish/v1/Systems/{{ cluster.name }}-cluster/{{ name | replace(".", "-") }}{% elif host.bmc.vendor == 'kubevirt-redfish' %}redfish-virtualmedia+https://{{ host.bmc.address }}/redfish/v1/Systems/{{ name | replace('.', '-') }}{% elif host.bmc.address is defined %}{{ host.bmc.address }}{% endif %}
      bmcCredentialsName:
        name: bmc-secret-{{ name }}{% endif %}{% set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first %}
      bootMACAddress: {{ bootNic.macAddress }}{% if host.bootMode is defined %}
      bootMode: {{ host.bootMode }}{% endif %}{% if host.storage is defined and host.storage.os is defined %}
      rootDeviceHints: {{ host.storage.os }}{% endif %}{% if host.automatedCleaningMode is defined %}
      automatedCleaningMode: {{ host.automatedCleaningMode }}{% endif %}{% if host.ironicInspect is defined %}
      ironicInspect: {{ host.ironicInspect }}{% endif %}{% if host.installerArgs is defined %}
      installerArgs: '{{ host.installerArgs }}'{% endif %}{% if host.ignitionConfigOverride is defined %}
      ignitionConfigOverride: '{{ host.ignitionConfigOverride }}'{% endif %}{% if host.nodeLabels is defined %}
      nodeLabels:{% for key, value in host.nodeLabels.items() %}
        {{ key }}: "{{ value }}"{% endfor %}{% endif %}{% if host.network is defined and host.network.interfaces is defined %}
      nodeNetwork:
        interfaces:{% for iface in host.network.interfaces %}
          - name: {{ iface.name }}
            macAddress: {{ iface.macAddress }}{% endfor %}
        config:
          interfaces:{% for iface in host.network.interfaces %}
            - name: {{ iface.name }}
              type: ethernet
              state: up{% endfor %}{% endif %}{% endfor %}
