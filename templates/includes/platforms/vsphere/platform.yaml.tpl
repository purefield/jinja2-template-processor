{% set vsphere = plugins.vsphere %}
{% set vcenter = vsphere.vcenter %}
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
{#- Static IP configuration (TechPreview in OCP 4.17+) -#}
{#- Enabled when hosts have network.primary.address defined -#}
{%- set staticHosts = [] %}
{%- for hostname, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
{%- set _ = staticHosts.append({'hostname': hostname, 'host': host}) %}
{%- endif %}
{%- endfor %}
{%- if staticHosts | length > 0 %}
    hosts:
{#- Bootstrap node (if defined in vsphere.bootstrap) -#}
{%- if vsphere.bootstrap is defined and vsphere.bootstrap.networkDevice is defined %}
      - role: bootstrap
{%- if vsphere.failureDomains is defined and vsphere.failureDomains | length > 0 %}
        failureDomain: {{ vsphere.failureDomains[0].name }}
{%- else %}
        failureDomain: {{ cluster.name }}-fd
{%- endif %}
        networkDevice:
          ipAddrs:
            - {{ vsphere.bootstrap.networkDevice.ipAddrs[0] }}
          gateway: {{ vsphere.bootstrap.networkDevice.gateway | default(network.primary.gateway, true) }}
{%- if vsphere.bootstrap.networkDevice.nameservers is defined or network.nameservers is defined %}
          nameservers:
{%- for ns in vsphere.bootstrap.networkDevice.nameservers | default(network.nameservers, true) %}
            - {{ ns }}
{%- endfor %}
{%- endif %}
{%- endif %}
{#- Control plane nodes -#}
{%- for item in staticHosts %}
{%- set host = item.host %}
{%- if host.role in ['control', 'master'] %}
      - role: control-plane
{%- if vsphere.failureDomains is defined and vsphere.failureDomains | length > 0 %}
        failureDomain: {{ host.failureDomain | default(vsphere.failureDomains[0].name, true) }}
{%- else %}
        failureDomain: {{ cluster.name }}-fd
{%- endif %}
        networkDevice:
          ipAddrs:
            - {{ host.network.primary.address }}/{{ (network.primary.subnet | default('0.0.0.0/24')).split('/')[1] }}
          gateway: {{ host.network.primary.gateway | default(network.primary.gateway, true) }}
{%- if host.network.primary.nameservers is defined or network.nameservers is defined %}
          nameservers:
{%- for ns in host.network.primary.nameservers | default(network.nameservers, true) %}
            - {{ ns }}
{%- endfor %}
{%- endif %}
{%- endif %}
{%- endfor %}
{#- Compute (worker) nodes -#}
{%- for item in staticHosts %}
{%- set host = item.host %}
{%- if host.role == 'worker' %}
      - role: compute
{%- if vsphere.failureDomains is defined and vsphere.failureDomains | length > 0 %}
        failureDomain: {{ host.failureDomain | default(vsphere.failureDomains[0].name, true) }}
{%- else %}
        failureDomain: {{ cluster.name }}-fd
{%- endif %}
        networkDevice:
          ipAddrs:
            - {{ host.network.primary.address }}/{{ (network.primary.subnet | default('0.0.0.0/24')).split('/')[1] }}
          gateway: {{ host.network.primary.gateway | default(network.primary.gateway, true) }}
{%- if host.network.primary.nameservers is defined or network.nameservers is defined %}
          nameservers:
{%- for ns in host.network.primary.nameservers | default(network.nameservers, true) %}
            - {{ ns }}
{%- endfor %}
{%- endif %}
{%- endif %}
{%- endfor %}
{%- endif -%}
