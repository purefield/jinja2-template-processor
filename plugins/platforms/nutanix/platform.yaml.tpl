{% set nutanix = plugins.nutanix %}
  nutanix:
    apiVIPs:{% for vip in network.primary.vips.api | as_list %}
      - {{ vip }}{%- endfor %}
    ingressVIPs:{% for vip in network.primary.vips.apps | as_list %}
      - {{ vip }}{%- endfor %}{% if nutanix.prismCentral is defined %}
    prismCentral:
      endpoint:
        address: {{ nutanix.prismCentral.endpoint.address }}
        port: {{ nutanix.prismCentral.endpoint.port | default(9440, true) }}
      username: {{ nutanix.prismCentral.username }}
      password: {{ load_file(nutanix.prismCentral.password) | trim }}{%- endif %}{% if nutanix.prismElements is defined %}
    prismElements:{% for pe in nutanix.prismElements %}
      - name: {{ pe.name }}
        endpoint:
          address: {{ pe.endpoint.address }}
          port: {{ pe.endpoint.port | default(9440, true) }}
        uuid: {{ pe.uuid }}{%- endfor %}{%- endif %}{% if nutanix.subnetUUIDs is defined %}
    subnetUUIDs:{% for subnet in nutanix.subnetUUIDs %}
      - {{ subnet }}{%- endfor %}{%- endif -%}
