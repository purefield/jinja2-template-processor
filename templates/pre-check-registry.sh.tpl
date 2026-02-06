{#- @meta
name: pre-check-registry.sh
description: Container registry connectivity verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{%- include 'includes/pre-check/common.sh.tpl' %}
{%- include 'includes/pre-check/registry.sh.tpl' %}

summary
