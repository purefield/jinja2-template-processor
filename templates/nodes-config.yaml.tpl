{#- @meta
name: nodes-config.yaml
description: Node network configuration snippet with NMState for each host
type: clusterfile
category: configuration
platforms:
  - baremetal
requires:
  - hosts.<hostname>.storage.os
  - hosts.<hostname>.network
docs: https://docs.openshift.com/container-platform/latest/installing/installing_with_agent_based_installer/preparing-to-install-with-agent-based-installer.html
-#}
hosts:{% for name,host in hosts.items() %}
- hostname: {{ name }}
  rootDeviceHints:  {{ host.storage.os }}
  networkConfig:{%- set nmstate %}{% include "includes/nmstate.yaml.tpl" %}{% endset -%}
{{ nmstate | indent(2,true) }}{% endfor %}
