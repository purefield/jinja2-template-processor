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
- kind: Namespace
  apiVersion: v1
  metadata:
    name: infinidat-csi
- kind: Namespace
  apiVersion: v1
  metadata:
    name: infinidat-csi-operator
- kind: Secret
  apiVersion: v1
  type: Opaque
  metadata:
    name: infinibox-creds
    namespace: infinidat-csi
    labels:
      app: infinidat-csi-driver
      app.kubernetes.io/created-by: controller-manager
      app.kubernetes.io/name: infiniboxcsidriver
      app.kubernetes.io/part-of: infinidat-csi-operator
      app.kubernetes.io/version: ''
  stringData: {{ config.infinidatCreds }}
- kind: RoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: allow-privileged
    namespace: infinidat-csi-operator
  subjects:
    - kind: ServiceAccount
      name: infinidat-csi-operator-controller-manager
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-driver
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-node
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-controller
      namespace: infinidat-csi-operator
  roleRef:
    kind: ClusterRole
    name: system:openshift:scc:privileged
    apiGroup: rbac.authorization.k8s.io
- kind: RoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: allow-anyuid
    namespace: infinidat-csi-operator
  subjects:
    - kind: ServiceAccount
      name: infinidat-csi-operator-controller-manager
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-driver
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-node
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-controller
      namespace: infinidat-csi-operator
  roleRef:
    kind: ClusterRole
    name: system:openshift:scc:anyuid
    apiGroup: rbac.authorization.k8s.io
- kind: RoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: allow-hostnetwork
    namespace: infinidat-csi-operator
  subjects:
    - kind: ServiceAccount
      name: infinidat-csi-operator-controller-manager
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-driver
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-node
      namespace: infinidat-csi-operator
    - kind: ServiceAccount
      name: infinidat-csi-operator-infinidat-csi-controller
      namespace: infinidat-csi-operator
  roleRef:
    kind: ClusterRole
    name: system:openshift:scc:hostnetwork
    apiGroup: rbac.authorization.k8s.io
- kind: StorageClass
  apiVersion: storage.k8s.io/v1
  metadata:
    name: ibox-fc-block-rwx
  provisioner: infinibox-csi-driver
  reclaimPolicy: Delete
  volumeBindingMode: Immediate
  allowVolumeExpansion: true
  parameters:
    csi.storage.k8s.io/controller-expand-secret-name: infinibox-creds
    csi.storage.k8s.io/controller-expand-secret-namespace: infinidat-csi
    csi.storage.k8s.io/controller-publish-secret-name: infinibox-creds
    csi.storage.k8s.io/controller-publish-secret-namespace: infinidat-csi
    csi.storage.k8s.io/node-publish-secret-name: infinibox-creds
    csi.storage.k8s.io/node-publish-secret-namespace: infinidat-csi
    csi.storage.k8s.io/node-stage-secret-name: infinibox-creds
    csi.storage.k8s.io/node-stage-secret-namespace: infinidat-csi
    csi.storage.k8s.io/provisioner-secret-name: infinibox-creds
    csi.storage.k8s.io/provisioner-secret-namespace: infinidat-csi
    csi.storage.k8s.io/node-expand-secret-name: infinibox-creds
    csi.storage.k8s.io/node-expand-secret-namespace: infinidat-csi
    csi.storage.k8s.io/fstype: ext4
    # Infinibox configuration
    pool_name: {{ storageClass.poolName }}
    storage_protocol: "fc"
    # optional parameters
    # max_vols_per_host: "100"
    # provision_type: "THIN"
    # ssd_enabled: "false"
    # unix_permissions: "777" # optional volume mount permissions
    uid: "3000" # UID of volume
    gid: "3000" # GID of volume
- kind: VolumeSnapshotClass
  apiVersion: snapshot.storage.k8s.io/v1
  metadata:
    name: ibox-snapshotclass
  driver: infinibox-csi-driver
  deletionPolicy: Delete
  parameters:
    csi.storage.k8s.io/snapshotter-secret-name: infinibox-creds
    csi.storage.k8s.io/snapshotter-secret-namespace: infinidat-csi
