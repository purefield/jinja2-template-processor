{# Azure IPI install-config.yaml template #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_azure/ipi/installing-azure-customizations.html #}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set azure = plugins.azure -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}
  platform:
    azure:
      type: {{ azure.controlPlane.type | default("Standard_D8s_v3", true) }}
{%- if azure.controlPlane.zones is defined %}
      zones:
{%- for zone in azure.controlPlane.zones %}
        - "{{ zone }}"
{%- endfor %}
{%- endif %}
{%- if azure.controlPlane.osDisk is defined %}
      osDisk:
        diskSizeGB: {{ azure.controlPlane.osDisk.diskSizeGB | default(1024, true) }}
        diskType: {{ azure.controlPlane.osDisk.diskType | default("Premium_LRS", true) }}
{%- endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}
    platform:
      azure:
        type: {{ azure.compute.type | default("Standard_D4s_v3", true) }}
{%- if azure.compute.zones is defined %}
        zones:
{%- for zone in azure.compute.zones %}
          - "{{ zone }}"
{%- endfor %}
{%- endif %}
{%- if azure.compute.osDisk is defined %}
        osDisk:
          diskSizeGB: {{ azure.compute.osDisk.diskSizeGB | default(128, true) }}
          diskType: {{ azure.compute.osDisk.diskType | default("Premium_LRS", true) }}
{%- endif %}

{%- if network.proxy is defined %}

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
  azure:
    baseDomainResourceGroupName: {{ azure.baseDomainResourceGroupName }}
    region: {{ azure.region }}
{%- if azure.cloudName is defined and azure.cloudName != "AzurePublicCloud" %}
    cloudName: {{ azure.cloudName }}
{%- endif %}
{%- if azure.networkResourceGroupName is defined %}
    networkResourceGroupName: {{ azure.networkResourceGroupName }}
{%- endif %}
{%- if azure.virtualNetwork is defined %}
    virtualNetwork: {{ azure.virtualNetwork }}
{%- endif %}
{%- if azure.controlPlaneSubnet is defined %}
    controlPlaneSubnet: {{ azure.controlPlaneSubnet }}
{%- endif %}
{%- if azure.computeSubnet is defined %}
    computeSubnet: {{ azure.computeSubnet }}
{%- endif %}
{%- if azure.outboundType is defined and azure.outboundType != "Loadbalancer" %}
    outboundType: {{ azure.outboundType }}
{%- endif %}

publish: External
pullSecret: '{{ load_file(account.pullSecret) | trim }}'
sshKey: |
{%- for pubKey in cluster.sshKeys %}
  {{ load_file(pubKey) | trim }}
{%- endfor %}
{%- if network.trustBundle is defined %}

additionalTrustBundle: |
{{ load_file(network.trustBundle) | indent(2, true) }}
{%- endif %}
{%- if cluster.mirrors is defined and cluster.mirrors | length > 0 %}

imageContentSources:
{%- for mirror in cluster.mirrors %}
  - source: {{ mirror.source }}
    mirrors:
{%- for m in mirror.mirrors %}
      - {{ m }}
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- if azure.credentials is defined %}

credentialsMode: Manual
{%- endif %}
