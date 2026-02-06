{#- @meta
name: pre-check-files.sh
description: Validate required files (pull secret, SSH keys, trust bundle, manifests)
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{%- include 'includes/pre-check/common.sh.tpl' %}
{%- include 'includes/pre-check/files.sh.tpl' %}

summary
