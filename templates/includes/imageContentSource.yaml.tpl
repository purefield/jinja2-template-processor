{%- for mirror in cluster.mirrors %}
- source: {{ mirror.source }}
  mirrors: {{ mirror.mirrors }}
  mirrorSourcePolicy: NeverContactSource
{% endfor -%}
