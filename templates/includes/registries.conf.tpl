{%- if cluster.mirrors -%}
unqualified-search-registries = ["registry.access.redhat.com", "docker.io"]
short-name-mode = ""{% for mirror in cluster.mirrors %}
[[registry]]{% if mirror.prefix %}
  prefix = "{{ mirror.prefix }}"{% endif %}
  location = "{{ mirror.source }}"
  mirror-by-digest-only = true
  [[registry.mirror]]{% for location in mirror.mirrors %}
    location = "{{ location }}"{% if mirror.insecure | default(false) %}
    insecure = true{% endif %}{% endfor %}
{% endfor %}{%- endif -%}
