{#- @meta
name: pre-check-ntp.sh
description: NTP server connectivity verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{%- include 'includes/pre-check/common.sh.tpl' %}
{%- include 'includes/pre-check/ntp.sh.tpl' %}

summary
