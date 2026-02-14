{% set gcp = plugins.gcp %}
{% set w = gcp.compute | default({}) %}
      gcp:
        type: {{ w.type | default("n2-standard-4", true) }}{% if w.zones is defined %}
        zones:{% for zone in w.zones %}
          - {{ zone }}{%- endfor %}{% endif %}{% if w.osDisk is defined %}
        osDisk:
          diskSizeGB: {{ w.osDisk.diskSizeGB | default(128, true) }}
          diskType: {{ w.osDisk.diskType | default("pd-ssd", true) }}{%- endif -%}
