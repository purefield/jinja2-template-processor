{% set osp = plugins.openstack %}
  openstack:
    cloud: {{ osp.cloud }}
    externalNetwork: {{ osp.externalNetwork }}{% if osp.apiFloatingIP is defined and osp.apiFloatingIP != "" %}
    apiFloatingIP: {{ osp.apiFloatingIP }}{%- endif %}{% if osp.ingressFloatingIP is defined and osp.ingressFloatingIP != "" %}
    ingressFloatingIP: {{ osp.ingressFloatingIP }}{%- endif %}{% if osp.machinesSubnet is defined %}
    machinesSubnet: {{ osp.machinesSubnet }}{%- endif %}{% if osp.trunkSupport is defined %}
    trunkSupport: {{ osp.trunkSupport | lower }}{%- endif %}{% if osp.octaviaSupport is defined %}
    octaviaSupport: {{ osp.octaviaSupport | lower }}{%- endif %}{% if network.primary.vips is defined %}
    apiVIPs:{% if network.primary.vips.api is iterable and network.primary.vips.api is not string %}{% for vip in network.primary.vips.api %}
      - {{ vip }}{%- endfor %}{% else %}
      - {{ network.primary.vips.api }}{%- endif %}
    ingressVIPs:{% if network.primary.vips.apps is iterable and network.primary.vips.apps is not string %}{% for vip in network.primary.vips.apps %}
      - {{ vip }}{%- endfor %}{% else %}
      - {{ network.primary.vips.apps }}{%- endif %}{%- endif -%}
