{% set azure = plugins.azure %}
    azure:
      type: {{ azure.controlPlane.type | default("Standard_D8s_v3", true) }}
{%- if azure.controlPlane.zones is defined %}
      zones:
{%- for zone in azure.controlPlane.zones %}
        - "{{ zone }}"
{%- endfor %}
{%- endif %}
{%- if azure.controlPlane.osDisk is defined %}
      osDisk:
        diskSizeGB: {{ azure.controlPlane.osDisk.diskSizeGB | default(1024, true) }}
        diskType: {{ azure.controlPlane.osDisk.diskType | default("Premium_LRS", true) }}
{%- endif -%}
