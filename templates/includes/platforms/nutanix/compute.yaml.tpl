{% set nutanix = plugins.nutanix %}
      nutanix:
        cpus: {{ nutanix.compute.cpus | default(4, true) }}
        coresPerSocket: {{ nutanix.compute.coresPerSocket | default(2, true) }}
        memoryMiB: {{ nutanix.compute.memoryMiB | default(16384, true) }}
        osDisk:
          diskSizeGiB: {{ nutanix.compute.osDisk.diskSizeGiB | default(120, true) }}
{%- if nutanix.compute.categories is defined %}
        categories:
{%- for cat in nutanix.compute.categories %}
          - key: {{ cat.key }}
            value: {{ cat.value }}
{%- endfor %}
{%- endif -%}
