{% set aws = plugins.aws %}
      aws:
        type: {{ aws.compute.type | default("m6i.xlarge", true) }}
{%- if aws.compute.zones is defined %}
        zones:
{%- for zone in aws.compute.zones %}
          - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if aws.compute.rootVolume is defined %}
        rootVolume:
          size: {{ aws.compute.rootVolume.size | default(120, true) }}
          type: {{ aws.compute.rootVolume.type | default("gp3", true) }}
{%- endif -%}
