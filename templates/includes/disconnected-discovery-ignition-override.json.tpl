{%- set ns = namespace(allowed=[]) -%}
{%- for mirror in cluster.mirrors | default([]) -%}
  {%- set source_key = mirror.prefix | default(mirror.source, true) -%}
  {%- if source_key and source_key not in ns.allowed -%}
    {%- set ns.allowed = ns.allowed + [source_key] -%}
  {%- endif -%}
  {%- for location in mirror.mirrors | default([]) -%}
    {%- if location and location not in ns.allowed -%}
      {%- set ns.allowed = ns.allowed + [location] -%}
    {%- endif -%}
  {%- endfor -%}
{%- endfor -%}
{%- set policy -%}
{"default":[{"type":"reject"}],"transports":{"docker":{{ "{" }}{%- for location in ns.allowed %}{% if not loop.first %},{% endif %}"{{ location }}":[{"type":"insecureAcceptAnything"}]{%- endfor %}}}}
{%- endset -%}
{"ignition":{"version":"3.1.0"},"storage":{"files":[{"path":"/etc/containers/policy.json","overwrite":true,"mode":420,"contents":{"source":"data:text/plain;charset=utf-8;base64,{{ policy | base64encode }}"}}]}}
