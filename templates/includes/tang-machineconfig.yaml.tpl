apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-master-tang-disk-encryption
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 3.4.0
    storage:
      luks:
        - name: root
          device: /dev/disk/by-partlabel/root
          clevis:
            tang:{% for server in cluster.diskEncryption.tang %}
              - url: {{ server.url }}
                thumbprint: {{ server.thumbprint }}{% endfor %}
          options:
            - --cipher
            - aes-cbc-essiv:sha256
          wipeVolume: true
      filesystems:
        - device: /dev/mapper/root
          format: xfs
          wipeFilesystem: true
          label: root
