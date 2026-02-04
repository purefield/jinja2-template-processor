{% set azure = plugins.azure %}
      azure:
        type: {{ azure.compute.type | default("Standard_D4s_v3", true) }}
{%- if azure.compute.zones is defined %}
        zones:
{%- for zone in azure.compute.zones %}
          - "{{ zone }}"
{%- endfor %}
{%- endif %}
{%- if azure.compute.osDisk is defined %}
        osDisk:
          diskSizeGB: {{ azure.compute.osDisk.diskSizeGB | default(128, true) }}
          diskType: {{ azure.compute.osDisk.diskType | default("Premium_LRS", true) }}
{%- endif -%}
