{#- @meta
name: cluster-overview.md
description: Customer-facing cluster overview document with clean formatting
type: clusterfile
category: documentation
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
  - cluster.name
  - network.domain
relatedTemplates:
  - install-config.yaml.tpl
  - pre-check.sh.tpl
docs: https://docs.openshift.com/container-platform/latest/installing/index.html
-#}
{%- set controlHosts = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list -%}
{%- set workerHosts  = hosts.values() | selectattr('role', 'equalto', 'worker') | list -%}
{%- set platform = cluster.platform | default('baremetal', true) -%}
{%- set platformNames = {
  'baremetal': 'Bare Metal (Agent-based)',
  'none': 'Single Node OpenShift',
  'aws': 'Amazon Web Services',
  'azure': 'Microsoft Azure',
  'gcp': 'Google Cloud Platform',
  'vsphere': 'VMware vSphere',
  'openstack': 'Red Hat OpenStack',
  'ibmcloud': 'IBM Cloud',
  'nutanix': 'Nutanix'
} -%}
# {{ cluster.name }}.{{ network.domain }}

OpenShift Container Platform {{ cluster.version | default('4.x') }} on {{ platformNames[platform] | default(platform) }}

---

## Cluster Identity

| | |
|---|---|
| **Cluster Name** | `{{ cluster.name }}` |
| **Base Domain** | `{{ network.domain }}` |
| **FQDN** | `{{ cluster.name }}.{{ network.domain }}` |
| **Platform** | {{ platformNames[platform] | default(platform) }} |
| **Version** | {{ cluster.version | default('—') }} |{% if cluster.arch is defined %}
| **Architecture** | {{ cluster.arch }} |{% endif %}{% if cluster.location is defined %}
| **Location** | {{ cluster.location }} |{% endif %}

---

## Topology

| Role | Count |
|------|-------|
| Control Plane | {{ controlHosts | length }} |
| Worker | {{ workerHosts | length }} |
| **Total** | **{{ hosts | length }}** |{% if controlHosts | length == 1 and workerHosts | length == 0 %}

> Single Node OpenShift — control plane and workloads run on one node.{% endif %}

---

## Network
{% if network.primary is defined %}
### Primary Network

| | |
|---|---|{% if network.primary.subnet is defined %}
| **Machine Network** | `{{ network.primary.subnet }}` |{% endif %}{% if network.primary.gateway is defined %}
| **Gateway** | `{{ network.primary.gateway }}` |{% endif %}{% if network.primary.type is defined %}
| **Network Type** | {{ network.primary.type }} |{% else %}
| **Network Type** | OVNKubernetes |{% endif %}{% if network.primary.mtu %}
| **MTU** | {{ network.primary.mtu }} |{% endif %}{% if network.primary.bond %}
| **Bond Mode** | `{{ network.primary.bond }}` |{% endif %}{% if network.primary.vlan %}
| **VLAN ID** | {{ network.primary.vlan }} |{% endif %}{% endif %}{% if network.cluster is defined %}

### Cluster Networks

| Network | CIDR | Details |
|---------|------|---------|{% if network.cluster.subnet is defined %}
| Cluster (pods) | `{{ network.cluster.subnet }}` | hostPrefix: /{{ network.cluster.hostPrefix | default(23) }} |{% endif %}{% if network.service is defined and network.service.subnet is defined %}
| Service | `{{ network.service.subnet }}` | — |{% endif %}{% if network.primary is defined and network.primary.subnet is defined %}
| Machine | `{{ network.primary.subnet }}` | — |{% endif %}{% endif %}{% if network.primary is defined and network.primary.vips is defined %}

### Virtual IPs

| Purpose | Address |
|---------|---------|{% for vip in network.primary.vips.api | default([]) %}
| API | `{{ vip }}` |{% endfor %}{% for vip in network.primary.vips.apps | default([]) %}
| Ingress (*.apps) | `{{ vip }}` |{% endfor %}{% endif %}{% if network.nameservers is defined %}

### DNS

| | |
|---|---|
| **Nameservers** | {% for ns in network.nameservers %}`{{ ns }}`{% if not loop.last %}, {% endif %}{% endfor %} |{% if network.dnsResolver is defined and network.dnsResolver.search is defined %}
| **Search Domains** | {% for s in network.dnsResolver.search %}`{{ s }}`{% if not loop.last %}, {% endif %}{% endfor %} |{% endif %}{% endif %}{% if network.ntpservers is defined %}

### NTP

{% for ntp in network.ntpservers %}- `{{ ntp }}`
{% endfor %}{% endif %}{% if network.proxy is defined %}

### Proxy

| | |
|---|---|
| **HTTP** | `{{ network.proxy.httpProxy }}` |
| **HTTPS** | `{{ network.proxy.httpsProxy }}` |
| **No Proxy** | `{{ network.proxy.noProxy }}` |{% endif %}

---
{%- set detailedHosts = [] -%}
{%- set simpleHosts = [] -%}
{%- for name, host in hosts.items() -%}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined -%}
{%- set _ = detailedHosts.append({'name': name, 'host': host}) -%}
{%- else -%}
{%- set _ = simpleHosts.append({'name': name, 'host': host}) -%}
{%- endif -%}
{%- endfor -%}
{% if detailedHosts | length > 0 %}
## Hosts
{% for item in detailedHosts %}
### {{ item.name }}

| | |
|---|---|
| **Role** | {{ 'Control Plane' if item.host.role in ['control', 'master'] else 'Worker' }} |
| **IP Address** | `{{ item.host.network.primary.address }}` |{% if item.host.bmc is defined %}
| **BMC** | `{{ item.host.bmc.address }}` ({{ item.host.bmc.vendor }}{% if item.host.bmc.version is defined %} v{{ item.host.bmc.version }}{% endif %}) |{% endif %}{% if item.host.storage is defined and item.host.storage.os is defined %}
| **Boot Disk** | {% if item.host.storage.os is mapping %}{% for k, v in item.host.storage.os.items() %}{{ k }}: `{{ v }}`{% if not loop.last %}, {% endif %}{% endfor %}{% else %}`{{ item.host.storage.os }}`{% endif %} |{% endif %}{% if item.host.network.interfaces is defined %}
| **NICs** | {% for iface in item.host.network.interfaces %}`{{ iface.name }}` {{ iface.macAddress }}{% if not loop.last %}, {% endif %}{% endfor %} |{% endif %}{% if item.host.network.primary.ports is defined %}
| **Bond Ports** | {% for p in item.host.network.primary.ports %}`{{ p }}`{% if not loop.last %}, {% endif %}{% endfor %} |{% endif %}
{% endfor %}
---
{% elif simpleHosts | length > 0 %}
## Hosts

| Hostname | Role |
|----------|------|{% for item in simpleHosts %}
| {{ item.name }} | {{ 'Control Plane' if item.host.role in ['control', 'master'] else 'Worker' }} |{% endfor %}

---
{% endif %}{% if cluster.mirrors is defined and cluster.mirrors | length > 0 %}
## Registry Mirrors

| Source | Mirror |
|--------|--------|{% for mirror in cluster.mirrors %}
| `{{ mirror.source }}` | {% for m in mirror.mirrors %}`{{ m }}`{% if not loop.last %}, {% endif %}{% endfor %} |{% endfor %}

---
{% endif %}{% if network.trustBundle is defined %}
## Trust

- Custom CA trust bundle: `{{ network.trustBundle }}`
{% endif %}{% if cluster.manifests is defined and cluster.manifests | length > 0 %}
## Additional Manifests

{% for manifest in cluster.manifests %}- `{{ manifest.name }}` — {{ manifest.file }}
{% endfor %}{% endif %}

{%- set hasDnsRecords = (network.primary is defined and network.primary.vips is defined) or detailedHosts | length > 0 -%}
{% if hasDnsRecords %}
---

## DNS Records Required

Before installation, create the following DNS records:

| Record | Type | Value |
|--------|------|-------|{% if network.primary is defined and network.primary.vips is defined %}{% for vip in network.primary.vips.api | default([]) %}
| `api.{{ cluster.name }}.{{ network.domain }}` | A | `{{ vip }}` |
| `api-int.{{ cluster.name }}.{{ network.domain }}` | A | `{{ vip }}` |{% endfor %}{% for vip in network.primary.vips.apps | default([]) %}
| `*.apps.{{ cluster.name }}.{{ network.domain }}` | A | `{{ vip }}` |{% endfor %}{% endif %}{% for item in detailedHosts %}
| `{{ item.name }}` | A | `{{ item.host.network.primary.address }}` |{% endfor %}{% endif %}

---

*Generated from clusterfile configuration. Verify all values before installation.*
