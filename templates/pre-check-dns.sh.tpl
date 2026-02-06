{#- @meta
name: pre-check-dns.sh
description: DNS forward and reverse lookup verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{%- include 'includes/pre-check/common.sh.tpl' %}
{%- include 'includes/pre-check/dns.sh.tpl' %}

summary
