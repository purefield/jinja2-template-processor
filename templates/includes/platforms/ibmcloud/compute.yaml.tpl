{% set ibm = plugins.ibmcloud %}
      ibmcloud:
        type: {{ ibm.compute.type | default("bx2-4x16", true) }}
{%- if ibm.compute.zones is defined %}
        zones:
{%- for zone in ibm.compute.zones %}
          - {{ zone }}
{%- endfor %}
{%- endif %}
