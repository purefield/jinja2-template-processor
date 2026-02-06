{% set aws = plugins.aws %}
{% set cp = aws.controlPlane | default({}) %}
    aws:
      type: {{ cp.type | default("m6i.xlarge", true) }}{% if cp.zones is defined %}
      zones:{% for zone in cp.zones %}
        - {{ zone }}{%- endfor %}{% endif %}{% if cp.rootVolume is defined %}
      rootVolume:
        size: {{ cp.rootVolume.size | default(120, true) }}
        type: {{ cp.rootVolume.type | default("gp3", true) }}{% if cp.rootVolume.iops is defined %}
        iops: {{ cp.rootVolume.iops }}{%- endif %}{%- endif -%}
