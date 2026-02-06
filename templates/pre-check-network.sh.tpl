{#- @meta
name: pre-check-network.sh
description: Network connectivity checks (hosts, gateway, VIPs, proxy)
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{%- include 'includes/pre-check/common.sh.tpl' %}
{%- include 'includes/pre-check/network.sh.tpl' %}

summary
