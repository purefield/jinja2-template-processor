{% set nutanix = plugins.nutanix %}
{% set w = nutanix.compute | default({}) %}
{% set disk = w.osDisk | default({}) %}
      nutanix:
        cpus: {{ w.cpus | default(4, true) }}
        coresPerSocket: {{ w.coresPerSocket | default(2, true) }}
        memoryMiB: {{ w.memoryMiB | default(16384, true) }}
        osDisk:
          diskSizeGiB: {{ disk.diskSizeGiB | default(120, true) }}{% if w.categories is defined %}
        categories:{% for cat in w.categories %}
          - key: {{ cat.key }}
            value: {{ cat.value }}{%- endfor %}{%- endif -%}
