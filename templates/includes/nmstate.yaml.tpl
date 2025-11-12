{% set nmstate %}{% include "nmstate.config.yaml.tpl" %}{% endset -%}
{{ nmstate | indent(2, true) }}
interfaces:{% for interface in host.network.interfaces %}
  - name: {{ interface.name }}
    macAddress: {{ interface.macAddress }}{% endfor %}
