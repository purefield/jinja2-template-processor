{% set aws = plugins.aws %}
    aws:
      type: {{ aws.controlPlane.type | default("m6i.xlarge", true) }}
{%- if aws.controlPlane.zones is defined %}
      zones:
{%- for zone in aws.controlPlane.zones %}
        - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if aws.controlPlane.rootVolume is defined %}
      rootVolume:
        size: {{ aws.controlPlane.rootVolume.size | default(120, true) }}
        type: {{ aws.controlPlane.rootVolume.type | default("gp3", true) }}
{%- if aws.controlPlane.rootVolume.iops is defined %}
        iops: {{ aws.controlPlane.rootVolume.iops }}
{%- endif %}
{%- endif -%}
