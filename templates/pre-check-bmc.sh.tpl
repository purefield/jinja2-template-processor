{#- @meta
name: pre-check-bmc.sh
description: BMC/Redfish connectivity verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{%- include 'includes/pre-check/common.sh.tpl' %}
{%- include 'includes/pre-check/bmc.sh.tpl' %}

summary
