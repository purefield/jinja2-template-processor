hosts:{% for name,host in hosts.items() %}
- hostname: {{ name }}
  rootDeviceHints:  {{ host.storage.os }}
  networkConfig:{%- set nmstate %}{% include "includes/nmstate.yaml.tpl" %}{% endset -%}
{{ nmstate | indent(2,true) }}{% endfor %}
