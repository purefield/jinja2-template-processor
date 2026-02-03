{# GCP IPI install-config.yaml template #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_gcp/ipi/installing-gcp-customizations.html #}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set gcp = plugins.gcp -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}
  platform:
    gcp:
      type: {{ gcp.controlPlane.type | default("n2-standard-4", true) }}
{%- if gcp.controlPlane.zones is defined %}
      zones:
{%- for zone in gcp.controlPlane.zones %}
        - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if gcp.controlPlane.osDisk is defined %}
      osDisk:
        diskSizeGB: {{ gcp.controlPlane.osDisk.diskSizeGB | default(128, true) }}
        diskType: {{ gcp.controlPlane.osDisk.diskType | default("pd-ssd", true) }}
{%- endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}
    platform:
      gcp:
        type: {{ gcp.compute.type | default("n2-standard-4", true) }}
{%- if gcp.compute.zones is defined %}
        zones:
{%- for zone in gcp.compute.zones %}
          - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if gcp.compute.osDisk is defined %}
        osDisk:
          diskSizeGB: {{ gcp.compute.osDisk.diskSizeGB | default(128, true) }}
          diskType: {{ gcp.compute.osDisk.diskType | default("pd-ssd", true) }}
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
  gcp:
    projectID: {{ gcp.projectID }}
    region: {{ gcp.region }}
{%- if gcp.network is defined %}
    network: {{ gcp.network }}
{%- endif %}
{%- if gcp.controlPlaneSubnet is defined %}
    controlPlaneSubnet: {{ gcp.controlPlaneSubnet }}
{%- endif %}
{%- if gcp.computeSubnet is defined %}
    computeSubnet: {{ gcp.computeSubnet }}
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
{%- if gcp.credentials is defined %}

credentialsMode: Manual
{%- endif %}
