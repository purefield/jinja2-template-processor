{% set nmstate %}{% set skipMacMapping=true %}{% include "nmstate.config.yaml.tpl" %}{% set skipMacMapping=none %}{% endset -%}
{{ nmstate | indent(2, true) }}
interfaces:{% for interface in host.network.interfaces %}
  - name: {{ interface.name }}
    macAddress: {{ interface.macAddress }}{% endfor %}
