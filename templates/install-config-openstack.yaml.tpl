{# OpenStack IPI install-config.yaml template #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_openstack/installing-openstack-installer-custom.html #}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set osp = plugins.openstack -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}
  platform:
    openstack:
      type: {{ osp.controlPlaneFlavor | default(osp.computeFlavor, true) | default("m1.xlarge", true) }}

compute:
  - name: worker
    replicas: {{ workerCount }}
    platform:
      openstack:
        type: {{ osp.computeFlavor | default("m1.xlarge", true) }}

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
  openstack:
    cloud: {{ osp.cloud }}
    externalNetwork: {{ osp.externalNetwork }}
{%- if osp.apiFloatingIP is defined and osp.apiFloatingIP != "" %}
    apiFloatingIP: {{ osp.apiFloatingIP }}
{%- endif %}
{%- if osp.ingressFloatingIP is defined and osp.ingressFloatingIP != "" %}
    ingressFloatingIP: {{ osp.ingressFloatingIP }}
{%- endif %}
{%- if osp.machinesSubnet is defined %}
    machinesSubnet: {{ osp.machinesSubnet }}
{%- endif %}
{%- if osp.trunkSupport is defined %}
    trunkSupport: {{ osp.trunkSupport | lower }}
{%- endif %}
{%- if osp.octaviaSupport is defined %}
    octaviaSupport: {{ osp.octaviaSupport | lower }}
{%- endif %}
{%- if network.primary.vips is defined %}
    apiVIPs:
{%- if network.primary.vips.api is iterable and network.primary.vips.api is not string %}
{%- for vip in network.primary.vips.api %}
      - {{ vip }}
{%- endfor %}
{%- else %}
      - {{ network.primary.vips.api }}
{%- endif %}
    ingressVIPs:
{%- if network.primary.vips.apps is iterable and network.primary.vips.apps is not string %}
{%- for vip in network.primary.vips.apps %}
      - {{ vip }}
{%- endfor %}
{%- else %}
      - {{ network.primary.vips.apps }}
{%- endif %}
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
