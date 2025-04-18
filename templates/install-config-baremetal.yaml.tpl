# https://docs.openshift.com/container-platform/latest/installing/installing_with_agent_based_installer/preparing-to-install-with-agent-based-installer.html
# rules for use with Agent installer
# - baremetal, vsphere, and none platforms are supported.
# - If `none` is used, the number of control plane replicas must be 1 and the total number of worker replicas must be 0.
# - apiVIPs and ingressVIPs parameters must be set for bare metal and vSphere platforms and not for `none`.
{%- set controlCount = hosts.values() | selectattr('role', 'equalto', 'control') | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker')  | list | length -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  replicas: {{ controlCount }}
  platform: {} # TODO

{%- if network.proxy %}
proxy: {{ network.proxy }}{% endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}{% if workerCount %}
    architecture: amd64
    hyperthreading: Enabled
    platform: {}{% endif %}

networking:
  networkType: {{ network.primary.type|default("OVNKubernetes", true) }}
  clusterNetwork:
    - cidr: {{ network.cluster.subnet }}
      hostPrefix: {{ network.cluster.hostPrefix }}
  machineNetwork:
    - cidr: {{ network.primary.subnet }}
  serviceNetwork:
    - {{ network.service.subnet }}

platform:{% if controlCount > 1 %}
  baremetal:
    apiVIPs: {{ network.primary.vips.api }}
    ingressVIPs: {{ network.primary.vips.apps }}{% else%}
  none: {}{% endif %}

publish: External
pullSecret: '{{load_file(account.pullSecret)|safe}}'
sshKey: '{{load_file(cluster.sshKey)|safe}}'
additionalTrustBundle: |
{{ load_file(network.trustBundle) | indent(2, true) }}
