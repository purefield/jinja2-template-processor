{%- set pw_hash = load_file(cluster.corePassword) | passwd_hash -%}
{%- if pw_hash %}
- apiVersion: machineconfiguration.openshift.io/v1
  kind: MachineConfig
  metadata:
    labels:
      machineconfiguration.openshift.io/role: master
    name: 99-set-core-user-password-master
  spec:
    config:
      ignition:
        version: 3.4.0
      passwd:
        users:
          - name: core
            passwordHash: "{{ pw_hash }}"
- apiVersion: machineconfiguration.openshift.io/v1
  kind: MachineConfig
  metadata:
    labels:
      machineconfiguration.openshift.io/role: worker
    name: 99-set-core-user-password-worker
  spec:
    config:
      ignition:
        version: 3.4.0
      passwd:
        users:
          - name: core
            passwordHash: "{{ pw_hash }}"
{%- endif %}
