{% set nutanix = plugins.nutanix %}
    nutanix:
      cpus: {{ nutanix.controlPlane.cpus | default(4, true) }}
      coresPerSocket: {{ nutanix.controlPlane.coresPerSocket | default(2, true) }}
      memoryMiB: {{ nutanix.controlPlane.memoryMiB | default(16384, true) }}
      osDisk:
        diskSizeGiB: {{ nutanix.controlPlane.osDisk.diskSizeGiB | default(120, true) }}
{%- if nutanix.controlPlane.categories is defined %}
      categories:
{%- for cat in nutanix.controlPlane.categories %}
        - key: {{ cat.key }}
          value: {{ cat.value }}
{%- endfor %}
{%- endif -%}
