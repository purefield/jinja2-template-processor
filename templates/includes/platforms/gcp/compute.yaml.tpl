{% set gcp = plugins.gcp %}
      gcp:
        type: {{ gcp.compute.type | default("n2-standard-4", true) }}
{%- if gcp.compute.zones is defined %}
        zones:
{%- for zone in gcp.compute.zones %}
          - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if gcp.compute.osDisk is defined %}
        osDisk:
          diskSizeGB: {{ gcp.compute.osDisk.diskSizeGB | default(128, true) }}
          diskType: {{ gcp.compute.osDisk.diskType | default("pd-ssd", true) }}
{%- endif -%}
