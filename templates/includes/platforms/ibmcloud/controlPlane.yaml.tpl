{% set ibm = plugins.ibmcloud %}
    ibmcloud:
      type: {{ ibm.controlPlane.type | default("bx2-4x16", true) }}
{%- if ibm.controlPlane.zones is defined %}
      zones:
{%- for zone in ibm.controlPlane.zones %}
        - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if ibm.controlPlane.bootVolume is defined %}
      bootVolume:
        encryptionKey: ""
{%- endif %}
