{% set nutanix = plugins.nutanix %}
{% set cp = nutanix.controlPlane | default({}) %}
{% set disk = cp.osDisk | default({}) %}
    nutanix:
      cpus: {{ cp.cpus | default(4, true) }}
      coresPerSocket: {{ cp.coresPerSocket | default(2, true) }}
      memoryMiB: {{ cp.memoryMiB | default(16384, true) }}
      osDisk:
        diskSizeGiB: {{ disk.diskSizeGiB | default(120, true) }}{% if cp.categories is defined %}
      categories:{% for cat in cp.categories %}
        - key: {{ cat.key }}
          value: {{ cat.value }}{%- endfor %}{%- endif -%}
