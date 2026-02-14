{#- @meta
name: siteconfig2clusterfile.yaml
description: Convert SiteConfig ClusterInstance CR to clusterfile format
type: generic
category: acm
platforms:
  - baremetal
  - none
requires:
  - spec.clusterName
  - spec.baseDomain
relatedTemplates:
  - clusterfile2siteconfig.yaml.tpl
docs: https://github.com/stolostron/siteconfig
-#}
{%- set s = spec -%}
{%- set platformMap = {"BareMetal": "baremetal", "None": "none", "VSphere": "vsphere", "AWS": "aws", "Azure": "azure", "GCP": "gcp", "External": "external"} -%}
{%- set platform = platformMap[s.platformType | default("BareMetal")] | default(s.platformType | default("baremetal") | lower) -%}
# Clusterfile generated from ClusterInstance {{ s.clusterName }}
account:
  pullSecret: pull-secret.json

cluster:
  name: {{ s.clusterName }}
  version: "{{ s.clusterImageSetNameRef | default("4.18.0") | regex_replace('^img', '') | regex_replace('-.*$', '') }}"
  platform: {{ platform }}{% if s.cpuArchitecture is defined %}
  arch: {{ s.cpuArchitecture }}{% endif %}{% if s.sshPublicKey is defined %}
  sshKeys:
    - ssh-key.pub{% endif %}
  location: default{% if s.clusterType is defined %}
  clusterType: {{ s.clusterType }}{% endif %}{% if s.cpuPartitioningMode is defined and s.cpuPartitioningMode != "None" %}
  cpuPartitioningMode: {{ s.cpuPartitioningMode }}{% endif %}{% if s.holdInstallation | default(false) %}
  holdInstallation: true{% endif %}{% if s.diskEncryption is defined %}{% if s.diskEncryption.type | default("none") == "tpm2" %}
  tpm: true{% elif s.diskEncryption.type == "tang" %}
  diskEncryption:
    type: tang
    tang:{% for server in s.diskEncryption.tang %}
      - url: {{ server.url }}
        thumbprint: {{ server.thumbprint }}{% endfor %}{% endif %}{% endif %}

network:
  domain: {{ s.baseDomain }}{% if s.machineNetwork is defined and s.machineNetwork | length > 0 %}
  primary:
    subnet: {{ s.machineNetwork[0].cidr }}{% if s.apiVIPs is defined %}
    vips:
      api:{% for vip in s.apiVIPs %}
        - {{ vip }}{% endfor %}
      apps:{% for vip in s.ingressVIPs %}
        - {{ vip }}{% endfor %}{% endif %}{% endif %}{% if s.clusterNetwork is defined and s.clusterNetwork | length > 0 %}
  cluster:
    subnet: {{ s.clusterNetwork[0].cidr }}{% if s.clusterNetwork[0].hostPrefix is defined %}
    hostPrefix: {{ s.clusterNetwork[0].hostPrefix }}{% endif %}{% endif %}{% if s.serviceNetwork is defined and s.serviceNetwork | length > 0 %}
  service:
    subnet: {{ s.serviceNetwork[0] if s.serviceNetwork[0] is string else s.serviceNetwork[0].cidr }}{% endif %}{% if s.proxy is defined %}
  proxy:{% if s.proxy.httpProxy is defined %}
    httpProxy: {{ s.proxy.httpProxy }}{% endif %}{% if s.proxy.httpsProxy is defined %}
    httpsProxy: {{ s.proxy.httpsProxy }}{% endif %}{% if s.proxy.noProxy is defined %}
    noProxy: {{ s.proxy.noProxy }}{% endif %}{% endif %}{% if s.additionalNTPSources is defined %}
  ntpservers:{% for ntp in s.additionalNTPSources %}
    - {{ ntp }}{% endfor %}{% endif %}
{% if s.nodes is defined %}
hosts:{% for node in s.nodes %}
  {{ node.hostName }}:
    role: {{ 'control' if node.role == 'master' else node.role }}{% if node.rootDeviceHints is defined %}
    storage:
      os: {{ node.rootDeviceHints }}{% endif %}{% if node.bmcAddress is defined %}
    bmc:
      address: {{ node.bmcAddress }}
      username: admin
      password: bmc-password.txt{% endif %}{% if node.bootMode is defined %}
    bootMode: {{ node.bootMode }}{% endif %}{% if node.automatedCleaningMode is defined %}
    automatedCleaningMode: {{ node.automatedCleaningMode }}{% endif %}{% if node.ironicInspect is defined %}
    ironicInspect: {{ node.ironicInspect }}{% endif %}{% if node.installerArgs is defined %}
    installerArgs: '{{ node.installerArgs }}'{% endif %}{% if node.ignitionConfigOverride is defined %}
    ignitionConfigOverride: '{{ node.ignitionConfigOverride }}'{% endif %}{% if node.nodeLabels is defined %}
    nodeLabels:{% for key, value in node.nodeLabels.items() %}
      {{ key }}: "{{ value }}"{% endfor %}{% endif %}{% if node.nodeNetwork is defined or node.bootMACAddress is defined %}
    network:{% if node.nodeNetwork is defined and node.nodeNetwork.interfaces is defined %}
      interfaces:{% for iface in node.nodeNetwork.interfaces %}
        - name: {{ iface.name }}
          macAddress: {{ iface.macAddress }}{% endfor %}{% endif %}
      primary:
        address: 0.0.0.0{% if node.nodeNetwork is defined and node.nodeNetwork.interfaces is defined %}
        ports:
          - {{ node.nodeNetwork.interfaces[0].name }}{% endif %}{% endif %}{% endfor %}{% endif %}
