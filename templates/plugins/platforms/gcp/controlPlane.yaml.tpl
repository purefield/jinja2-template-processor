{% set gcp = plugins.gcp %}
{% set cp = gcp.controlPlane | default({}) %}
    gcp:
      type: {{ cp.type | default("n2-standard-4", true) }}{% if cp.zones is defined %}
      zones:{% for zone in cp.zones %}
        - {{ zone }}{%- endfor %}{% endif %}{% if cp.osDisk is defined %}
      osDisk:
        diskSizeGB: {{ cp.osDisk.diskSizeGB | default(128, true) }}
        diskType: {{ cp.osDisk.diskType | default("pd-ssd", true) }}{%- endif -%}
