{% set nutanix = plugins.nutanix %}
{% set w = nutanix.compute | default({}) %}
{% set disk = w.osDisk | default({}) %}
{% set cm = cluster.machine.worker if cluster.machine is defined and cluster.machine.worker is defined else {} %}
{% set cms = cm.storage | default({}) %}
      nutanix:
        cpus: {{ (cm.cpus * (cm.sockets | default(1))) if cm.cpus is defined else w.cpus | default(4, true) }}
        coresPerSocket: {{ cm.cpus | default(w.coresPerSocket | default(2, true), true) }}
        memoryMiB: {{ (cm.memory * 1024) if cm.memory is defined else w.memoryMiB | default(16384, true) }}
        osDisk:
          diskSizeGiB: {{ cms.os | default(disk.diskSizeGiB | default(120, true), true) }}{% if w.categories is defined %}
        categories:{% for cat in w.categories %}
          - key: {{ cat.key }}
            value: {{ cat.value }}{%- endfor %}{%- endif -%}
