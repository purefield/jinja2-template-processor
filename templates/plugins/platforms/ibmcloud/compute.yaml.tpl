{% set ibm = plugins.ibmcloud %}
{% set w = ibm.compute | default({}) %}
      ibmcloud:
        type: {{ w.type | default("bx2-4x16", true) }}{% if w.zones is defined %}
        zones:{% for zone in w.zones %}
          - {{ zone }}{%- endfor %}{%- endif %}
