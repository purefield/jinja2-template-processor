{% set vsphere = plugins.vsphere %}
{% set cm = cluster.machine.worker if cluster.machine is defined and cluster.machine.worker is defined else {} %}
{% set cms = cm.storage | default({}) %}
      vsphere:
        cpus: {{ (cm.cpus * (cm.sockets | default(1))) if cm.cpus is defined else vsphere.cpus | default(4, true) }}
        coresPerSocket: {{ cm.cpus | default(vsphere.coresPerSocket | default(4, true), true) }}
        memoryMB: {{ (cm.memory * 1024) if cm.memory is defined else vsphere.memoryMiB | default(16384, true) }}
        osDisk:
          diskSizeGB: {{ cms.os | default(vsphere.diskGiB | default(120, true), true) }}
