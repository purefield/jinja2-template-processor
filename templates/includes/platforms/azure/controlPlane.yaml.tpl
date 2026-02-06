{% set azure = plugins.azure %}
{% set cp = azure.controlPlane | default({}) %}
    azure:
      type: {{ cp.type | default("Standard_D8s_v3", true) }}{% if cp.zones is defined %}
      zones:{% for zone in cp.zones %}
        - "{{ zone }}"{%- endfor %}{% endif %}{% if cp.osDisk is defined %}
      osDisk:
        diskSizeGB: {{ cp.osDisk.diskSizeGB | default(1024, true) }}
        diskType: {{ cp.osDisk.diskType | default("Premium_LRS", true) }}{%- endif -%}
