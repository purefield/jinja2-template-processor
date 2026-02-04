{% set gcp = plugins.gcp %}
    gcp:
      type: {{ gcp.controlPlane.type | default("n2-standard-4", true) }}
{%- if gcp.controlPlane.zones is defined %}
      zones:
{%- for zone in gcp.controlPlane.zones %}
        - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if gcp.controlPlane.osDisk is defined %}
      osDisk:
        diskSizeGB: {{ gcp.controlPlane.osDisk.diskSizeGB | default(128, true) }}
        diskType: {{ gcp.controlPlane.osDisk.diskType | default("pd-ssd", true) }}
{%- endif -%}
