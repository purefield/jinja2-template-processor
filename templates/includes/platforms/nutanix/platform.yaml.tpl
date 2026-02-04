{% set nutanix = plugins.nutanix %}
  nutanix:
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
    prismCentral:
      endpoint:
        address: {{ nutanix.prismCentral.endpoint.address }}
        port: {{ nutanix.prismCentral.endpoint.port | default(9440, true) }}
      username: {{ nutanix.prismCentral.username }}
      password: {{ load_file(nutanix.prismCentral.password) | trim }}
    prismElements:
{%- for pe in nutanix.prismElements %}
      - name: {{ pe.name }}
        endpoint:
          address: {{ pe.endpoint.address }}
          port: {{ pe.endpoint.port | default(9440, true) }}
        uuid: {{ pe.uuid }}
{%- endfor %}
    subnetUUIDs:
{%- for subnet in nutanix.subnetUUIDs %}
      - {{ subnet }}
{%- endfor -%}
