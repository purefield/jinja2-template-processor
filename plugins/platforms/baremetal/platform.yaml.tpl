{%- if network.primary.vips is defined %}
  baremetal:
    apiVIPs:{% for vip in network.primary.vips.api | as_list %}
      - {{ vip }}{%- endfor %}
    ingressVIPs:{% for vip in network.primary.vips.apps | as_list %}
      - {{ vip }}{%- endfor %}
{%- else %}
  baremetal: {}
{%- endif %}
