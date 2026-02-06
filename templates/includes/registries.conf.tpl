{%- if cluster.mirrors -%}
unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]
short-name-mode = ""{% for mirror in cluster.mirrors %}
[[registry]]
  prefix = "{{ mirror.prefix }}"
  location = "{{ mirror.source }}"
  mirror-by-digest-only = true
  [[registry.mirror]]{% for location in mirror.mirrors %}
    location = "{{ location }}"{% endfor %}
{% endfor %}{%- endif -%}
