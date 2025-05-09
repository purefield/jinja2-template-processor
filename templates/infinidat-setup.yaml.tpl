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
  stringData: {{ load_file(config.infinidatCreds) }}
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
    apiVersion: operators.coreos.com/v1
- kind: OperatorGroup
  apiVersion: operators.coreos.com/v1
  metadata:
    annotations:
      olm.providedAPIs: 'Iboxreplica.v1.csidriver.infinidat.com,InfiniboxCsiDriver.v1alpha1.csidriver.infinidat.com'
    name: infinidat-csi
    namespace: infinidat-csi
  spec:
    targetNamespaces:
      - infinidat-csi
    upgradeStrategy: Default
- kind: Subscription
  apiVersion: operators.coreos.com/v1alpha1
  metadata:
    labels:
      operators.coreos.com/infinibox-operator-certified.infinidat-csi: ''
    name: infinibox-operator-certified
    namespace: infinidat-csi
  spec:
    channel: stable
    installPlanApproval: Automatic
    name: infinibox-operator-certified
    source: certified-operators
    sourceNamespace: openshift-marketplace
    startingCSV: infinibox-operator-certified.v2.20.0
- kind: InfiniboxCsiDriver
  apiVersion: csidriver.infinidat.com/v1alpha1
  metadata:
    labels:
      app.kubernetes.io/created-by: infinibox-operator-certified
      app.kubernetes.io/instance: infiniboxcsidriver-sample
      app.kubernetes.io/managed-by: kustomize
      app.kubernetes.io/name: infiniboxcsidriver
      app.kubernetes.io/part-of: infinibox-operator-certified
    name: infinibox-csi-driver
    namespace: infinidat-csi
  spec:
    logLevel: debug
    nodeSelector:
      kubernetes.io/os: linux
    csiDriverName: infinibox-csi-driver
    removeDomainName: false
    createEvents: true
    csiDriverVersion: v2.20.0
    replicaCount: 1
    volumeNamePrefix: ibox
    e2etesting: false
    autoUpdate: false
    instanceCount: 1
    skipCredentialsCreation: true
    images:
      # https://github.com/Infinidat/infinibox-csi-driver/blob/77478fd7cfe0216da421d8826d812b17bea6dd34/deploy/helm/infinibox-csi-driver/values.yaml
      snapshottersidecar: 'registry.k8s.io/sig-storage/csi-snapshotter@sha256:339a83a86e6e1eead14413fe494b43de8bc48243d146c2810b39dd741d26ca6a'
      csidriver: 'registry.connect.redhat.com/infinidat/infinibox-csidriver-certified@sha256:22eb763eec637d66f95401b591d26d845bfbe9a745d0c9b25adaaf643a336830'
      attachersidecar: 'registry.k8s.io/sig-storage/csi-attacher@sha256:47ab8aebebdc59316004ba8d51a903637d808f4e62a6d0f599ed3c2483cea901'
      registrarsidecar: 'registry.k8s.io/sig-storage/csi-node-driver-registrar@sha256:f032a0ca4c699eebe403988a0e217c3dfc82e2cee8b7d9d247a493e5a2425f24'
      livenesssidecar: 'registry.k8s.io/sig-storage/livenessprobe@sha256:13f6b1f9d0514b859e549e20b731d93c90a144186deb68bfc931e3dbf9041afc'
      provisionersidecar: 'registry.k8s.io/sig-storage/csi-provisioner@sha256:67ee5137252811fd471b8571efe9e173145ec8af7b520861eeccf7c078a772f2'
      resizersidecar: 'registry.k8s.io/sig-storage/csi-resizer@sha256:706f7cdcccd30ca5f0e94d548e2e0c658f69c0fe4b68a5bf37818a04ca618d3d'
      livenesssidecar_pull_policy: IfNotPresent
      provisionersidecar_pull_policy: IfNotPresent
      resizersidecar_pull_policy: IfNotPresent
      snapshottersidecar_pull_policy: IfNotPresent
      csidriver_pull_policy: Always
      attachersidecar_pull_policy: IfNotPresent
      registrarsidecar_pull_policy: IfNotPresent
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
    pool_name: {{ storageClass.poolname }}
    storage_protocol: "fc"
    # optional parameters
    unix_permissions: "777" # optional volume mount permissions
    # max_vols_per_host: "100"
    # provision_type: "THIN"
    # ssd_enabled: "false"
    # uid: "3000" # UID of volume
    # gid: "3000" # GID of volume
- kind: VolumeSnapshotClass
  apiVersion: snapshot.storage.k8s.io/v1
  metadata:
    name: ibox-snapshotclass
  driver: infinibox-csi-driver
  deletionPolicy: Delete
  parameters:
    csi.storage.k8s.io/snapshotter-secret-name: infinibox-creds
    csi.storage.k8s.io/snapshotter-secret-namespace: infinidat-csi
