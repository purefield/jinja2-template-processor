{%- set ns = namespace(first=true) -%}
{%- set policy -%}
{"default":[{"type":"reject"}],"transports":{"docker":{{ "{" }}{%- for mirror in cluster.mirrors | default([]) %}{%- for location in mirror.mirrors %}{% if not ns.first %},{% endif %}"{{ location }}":[{"type":"insecureAcceptAnything"}]{% set ns.first = false %}{%- endfor %}{%- endfor %}}}}
{%- endset -%}
{"ignition":{"version":"3.1.0"},"storage":{"files":[{"path":"/etc/containers/policy.json","overwrite":true,"mode":420,"contents":{"source":"data:text/plain;charset=utf-8;base64,{{ policy | base64encode }}"}}]}}
