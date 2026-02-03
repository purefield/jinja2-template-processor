{# IBM Cloud IPI install-config.yaml template #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_ibm_cloud/ipi/installing-ibm-cloud-customizations.html #}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set ibm = plugins.ibmcloud -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}
  platform:
    ibmcloud:
      type: {{ ibm.controlPlane.type | default("bx2-4x16", true) }}
{%- if ibm.controlPlane.zones is defined %}
      zones:
{%- for zone in ibm.controlPlane.zones %}
        - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if ibm.controlPlane.bootVolume is defined %}
      bootVolume:
        encryptionKey: ""
{%- endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}
    platform:
      ibmcloud:
        type: {{ ibm.compute.type | default("bx2-4x16", true) }}
{%- if ibm.compute.zones is defined %}
        zones:
{%- for zone in ibm.compute.zones %}
          - {{ zone }}
{%- endfor %}
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
  ibmcloud:
    region: {{ ibm.region }}
    resourceGroupName: {{ ibm.resourceGroupName }}
{%- if ibm.vpcName is defined %}
    vpcName: {{ ibm.vpcName }}
{%- endif %}
{%- if ibm.controlPlaneSubnets is defined and ibm.controlPlaneSubnets | length > 0 %}
    controlPlaneSubnets:
{%- for subnet in ibm.controlPlaneSubnets %}
      - {{ subnet }}
{%- endfor %}
{%- endif %}
{%- if ibm.computeSubnets is defined and ibm.computeSubnets | length > 0 %}
    computeSubnets:
{%- for subnet in ibm.computeSubnets %}
      - {{ subnet }}
{%- endfor %}
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
{%- if ibm.credentials is defined %}

credentialsMode: Manual
{%- endif %}
