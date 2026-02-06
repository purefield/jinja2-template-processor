{% set ibm = plugins.ibmcloud %}
{% set cp = ibm.controlPlane | default({}) %}
    ibmcloud:
      type: {{ cp.type | default("bx2-4x16", true) }}{% if cp.zones is defined %}
      zones:{% for zone in cp.zones %}
        - {{ zone }}{%- endfor %}{% endif %}{% if cp.bootVolume is defined %}
      bootVolume:
        encryptionKey: ""{%- endif %}
