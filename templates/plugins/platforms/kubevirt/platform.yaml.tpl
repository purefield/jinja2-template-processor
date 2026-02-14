{%- if network.primary.vips is defined %}
  baremetal:
    apiVIPs:{% if network.primary.vips.api is iterable and network.primary.vips.api is not string %}{% for vip in network.primary.vips.api %}
      - {{ vip }}{%- endfor %}{% else %}
      - {{ network.primary.vips.api }}{%- endif %}
    ingressVIPs:{% if network.primary.vips.apps is iterable and network.primary.vips.apps is not string %}{% for vip in network.primary.vips.apps %}
      - {{ vip }}{%- endfor %}{% else %}
      - {{ network.primary.vips.apps }}{%- endif %}
{%- else %}
  none: {}
{%- endif %}
