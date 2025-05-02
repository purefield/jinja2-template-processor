# bond the primary interface and use a VLAN interface for br-ex
# after install, provision br-vmdata directly on bond0
{% set firstHostName,firstHost = hosts.items() | first %}
{% set enabledFalse='{"enabled":false}' %}
---
apiVersion: v1alpha1
kind: AgentConfig
metadata:
  name: {{ cluster.name }}
rendezvousIP: {{ firstHost.network.primary.address }}
additionalNTPSources: {{ network.ntpservers }}
hosts:{% for name,host in hosts.items() %}
  - hostname: {{ name }}{% if host.storage.os %}
    rootDeviceHints: {{ host.storage.os }}{% endif %}
    networkConfig:{%- set nmstate %}{% include "includes/nmstate.yaml.tpl" %}{% endset -%}
{{ nmstate | indent(4,true) }}{% endfor %}

