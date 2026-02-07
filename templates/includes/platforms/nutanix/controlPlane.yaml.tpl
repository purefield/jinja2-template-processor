{% set nutanix = plugins.nutanix %}
{% set cp = nutanix.controlPlane | default({}) %}
{% set disk = cp.osDisk | default({}) %}
{% set cm = cluster.machine.control if cluster.machine is defined and cluster.machine.control is defined else {} %}
{% set cms = cm.storage | default({}) %}
    nutanix:
      cpus: {{ (cm.cpus * (cm.sockets | default(1))) if cm.cpus is defined else cp.cpus | default(4, true) }}
      coresPerSocket: {{ cm.cpus | default(cp.coresPerSocket | default(2, true), true) }}
      memoryMiB: {{ (cm.memory * 1024) if cm.memory is defined else cp.memoryMiB | default(16384, true) }}
      osDisk:
        diskSizeGiB: {{ cms.os | default(disk.diskSizeGiB | default(120, true), true) }}{% if cp.categories is defined %}
      categories:{% for cat in cp.categories %}
        - key: {{ cat.key }}
          value: {{ cat.value }}{%- endfor %}{%- endif -%}
