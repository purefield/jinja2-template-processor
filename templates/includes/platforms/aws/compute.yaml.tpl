{% set aws = plugins.aws %}
{% set w = aws.compute | default({}) %}
      aws:
        type: {{ w.type | default("m6i.xlarge", true) }}{% if w.zones is defined %}
        zones:{% for zone in w.zones %}
          - {{ zone }}{%- endfor %}{% endif %}{% if w.rootVolume is defined %}
        rootVolume:
          size: {{ w.rootVolume.size | default(120, true) }}
          type: {{ w.rootVolume.type | default("gp3", true) }}{%- endif -%}
