{# vSphere IPI install-config.yaml template #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_vsphere/ipi/installing-vsphere-installer-provisioned.html #}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set vsphere = plugins.vsphere -%}
{%- set vcenter = vsphere.vcenter -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}
  platform:
    vsphere:
      cpus: {{ vsphere.cpus | default(4, true) }}
      coresPerSocket: {{ vsphere.coresPerSocket | default(4, true) }}
      memoryMB: {{ vsphere.memoryMiB | default(16384, true) }}
      osDisk:
        diskSizeGB: {{ vsphere.diskGiB | default(120, true) }}

compute:
  - name: worker
    replicas: {{ workerCount }}
    platform:
      vsphere:
        cpus: {{ vsphere.cpus | default(4, true) }}
        coresPerSocket: {{ vsphere.coresPerSocket | default(4, true) }}
        memoryMB: {{ vsphere.memoryMiB | default(16384, true) }}
        osDisk:
          diskSizeGB: {{ vsphere.diskGiB | default(120, true) }}

{%- if network.proxy %}

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
  vsphere:
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
    vcenters:
      - server: {{ vcenter.server }}
        user: {{ vcenter.username }}
        password: {{ load_file(vcenter.password) | trim }}
        datacenter: {{ vcenter.datacenter }}
        defaultDatastore: {{ vcenter.defaultDatastore }}
{%- if vsphere.failureDomains is defined and vsphere.failureDomains | length > 0 %}
    failureDomains:
{%- for fd in vsphere.failureDomains %}
      - name: {{ fd.name }}
        region: {{ fd.region }}
        zone: {{ fd.zone }}
        topology:
          datacenter: {{ fd.datacenter | default(vcenter.datacenter, true) }}
          computeCluster: /{{ fd.datacenter | default(vcenter.datacenter, true) }}/host/{{ fd.cluster | default(vcenter.cluster, true) }}
          networks:
            - {{ fd.network | default(vsphere.network, true) }}
          datastore: /{{ fd.datacenter | default(vcenter.datacenter, true) }}/datastore/{{ fd.datastore | default(vcenter.defaultDatastore, true) }}
{%- if fd.resourcePool is defined or vcenter.resourcePool is defined %}
          resourcePool: /{{ fd.datacenter | default(vcenter.datacenter, true) }}/host/{{ fd.cluster | default(vcenter.cluster, true) }}/Resources/{{ fd.resourcePool | default(vcenter.resourcePool, true) }}
{%- endif %}
{%- if fd.folder is defined or vcenter.folder is defined %}
          folder: /{{ fd.datacenter | default(vcenter.datacenter, true) }}/vm/{{ fd.folder | default(vcenter.folder, true) }}
{%- endif %}
{%- endfor %}
{%- else %}
    failureDomains:
      - name: {{ cluster.name }}-fd
        region: {{ cluster.location | default("region1", true) }}
        zone: {{ cluster.location | default("zone1", true) }}
        topology:
          datacenter: {{ vcenter.datacenter }}
          computeCluster: /{{ vcenter.datacenter }}/host/{{ vcenter.cluster }}
          networks:
            - {{ vsphere.network }}
          datastore: /{{ vcenter.datacenter }}/datastore/{{ vcenter.defaultDatastore }}
{%- if vcenter.resourcePool is defined %}
          resourcePool: /{{ vcenter.datacenter }}/host/{{ vcenter.cluster }}/Resources/{{ vcenter.resourcePool }}
{%- endif %}
{%- if vcenter.folder is defined %}
          folder: /{{ vcenter.datacenter }}/vm/{{ vcenter.folder }}
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
