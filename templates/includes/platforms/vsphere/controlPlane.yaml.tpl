{% set vsphere = plugins.vsphere %}
    vsphere:
      cpus: {{ vsphere.cpus | default(4, true) }}
      coresPerSocket: {{ vsphere.coresPerSocket | default(4, true) }}
      memoryMB: {{ vsphere.memoryMiB | default(16384, true) }}
      osDisk:
        diskSizeGB: {{ vsphere.diskGiB | default(120, true) }}
