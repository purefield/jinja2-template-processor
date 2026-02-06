{% set azure = plugins.azure %}
{% set w = azure.compute | default({}) %}
      azure:
        type: {{ w.type | default("Standard_D4s_v3", true) }}{% if w.zones is defined %}
        zones:{% for zone in w.zones %}
          - "{{ zone }}"{%- endfor %}{% endif %}{% if w.osDisk is defined %}
        osDisk:
          diskSizeGB: {{ w.osDisk.diskSizeGB | default(128, true) }}
          diskType: {{ w.osDisk.diskType | default("Premium_LRS", true) }}{%- endif -%}
