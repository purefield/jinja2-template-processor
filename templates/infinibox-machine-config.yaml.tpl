apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:
- kind: MachineConfig
  # MachineConfig for /etc/multipath.conf
  apiVersion: machineconfiguration.openshift.io/v1
  metadata:
    name: 99-worker-infinidat-multipath
    labels:
      machineconfiguration.openshift.io/role: worker
  spec:
    config:
      ignition:
        version: 3.2.0
      systemd:
        units:
          - name: multipathd.service
            enabled: true
      storage:
        files:
          - path: /etc/multipath.conf
            mode: 0644
            contents:
              source: data:;base64,{{ load_file(config.multipathConf)|base64encode }}
- kind: MachineConfig
  # MachineConfig for FC driver tuning: /etc/modprobe.d/infinidat.conf
  apiVersion: machineconfiguration.openshift.io/v1
  metadata:
    name: 99-worker-infinidat-fc-driver
    labels:
      machineconfiguration.openshift.io/role: worker
  spec:
    config:
      ignition:
        version: 3.2.0
      storage:
        files:
          - path: /etc/modprobe.d/infinidat.conf
            mode: 0644
            contents:
              source: data:;base64,{{ load_file(config.infinidatConf)|base64encode }}
- kind: MachineConfig
  # MachineConfig for udev queue tuning
  apiVersion: machineconfiguration.openshift.io/v1
  metadata:
    name: 99-worker-infinidat-udev
    labels:
      machineconfiguration.openshift.io/role: worker
  spec:
    config:
      ignition:
        version: 3.2.0
      storage:
        files:
          - path: /etc/udev/rules.d/99-infinidat-queue.rules
            mode: 0644
            contents:
              source: data:;base64,{{ load_file(config.infinidatRules)|base64encode }}
