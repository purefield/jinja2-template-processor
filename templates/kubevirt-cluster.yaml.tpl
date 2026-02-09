{#- @meta
name: kubevirt-cluster.yaml
description: KubeVirt VirtualMachine resources for OpenShift Virtualization cluster provisioning
type: clusterfile
category: installation
platforms:
  - kubevirt
requires:
  - cluster.name
  - cluster.machine
  - hosts.<hostname>.network.interfaces
relatedTemplates:
  - kubevirt-install-iso.yaml.tpl
  - acm-ztp.yaml.tpl
  - acm-capi-m3.yaml.tpl
docs: https://docs.openshift.com/container-platform/4.20/virt/about_virt/about-virt.html
-#}
{%- set kv = plugins.kubevirt | default({}) -%}
{%- set cm = cluster.machine | default({}) -%}
{%- set controlMachine = cm.control | default({}) -%}
{%- set workerMachine  = cm.worker | default({}) -%}
{%- set kvsc = kv.storageClass | default({}) -%}
{%- set defaultSC = kvsc.default | default("lvms-vg1") -%}
{%- set kvmap = kv.storageMapping | default({}) -%}
{%- set nsKey = kv.nodeSelector | default("") -%}
{%- set namespace = cluster.name + "-cluster" -%}
{%- set bootDelivery = bootDelivery | default("bmc") -%}
{%- set hasIsoDisk = true if bootDelivery == 'iso' else false -%}
apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:
- kind: Namespace
  apiVersion: v1
  metadata:
    name: {{ namespace }}
- kind: UserDefinedNetwork
  apiVersion: k8s.ovn.org/v1
  metadata:
    name: virtualmachine-net
    namespace: {{ namespace }}
  spec:
    topology: Layer2
    layer2:
      role: Secondary
      ipam:
        mode: Disabled{% for name, host in hosts.items() %}
{%- set vmname  = name.replace('.', '-') -%}
{%- set role    = 'master' if host.role == 'control' else 'worker' -%}
{%- set roleMachine = controlMachine if host.role == 'control' else workerMachine -%}
{%- set hm = host.machine if host.machine is defined else roleMachine -%}
{%- set hms = hm.storage | default({}) -%}
{%- set memory  = hm.memory | default(64) -%}
{%- set cores   = hm.cpus | default(16) -%}
{%- set sockets = hm.sockets | default(1) -%}
{%- set osDiskSize = hms.os | default(120) -%}
{%- set dataDisks = hms.data | default([]) -%}
{%- set ifname  = host.network.interfaces[0].name -%}
{%- set macaddr = host.network.interfaces[0].macAddress -%}
{%- set roleMap = kvmap[host.role] | default(kvmap.control | default({})) -%}
{%- set osClassLabel = roleMap.os | default("default") -%}
{%- set dataClassLabel = roleMap.data | default(osClassLabel) -%}
{%- set ossc = kvsc[osClassLabel] | default(defaultSC) -%}
{%- set datasc = kvsc[dataClassLabel] | default(defaultSC) -%}
{%- set vgNode  = (loop.index - 1) % 3 + 1 %}
- kind: PersistentVolumeClaim
  apiVersion: v1
  metadata:
    name: {{ vmname }}
    namespace: {{ namespace }}
  spec:
    accessModes:
      - ReadWriteOnce
    volumeMode: Block
    resources:
      requests:
        storage: {{ osDiskSize }}Gi
    storageClassName: {{ ossc }}{% for diskSize in dataDisks %}
- kind: PersistentVolumeClaim
  apiVersion: v1
  metadata:
    name: {{ vmname }}-data-{{ loop.index0 }}
    namespace: {{ namespace }}
  spec:
    accessModes:
      - ReadWriteOnce
    volumeMode: Block
    resources:
      requests:
        storage: {{ diskSize }}Gi
    storageClassName: {{ datasc }}{% endfor %}
- kind: VirtualMachine
  apiVersion: kubevirt.io/v1
  metadata:
    name: {{ vmname }}
    namespace: {{ namespace }}
    labels:
      app.kubernetes.io/part-of: {{ cluster.name }}
      cluster: {{ cluster.name }}
  spec:
    runStrategy: RerunOnFailure{% if hasIsoDisk %}
    dataVolumeTemplates:
      - metadata:
          creationTimestamp: null
          name: {{ cluster.name }}-vm-install-iso
        spec:
          source:
            pvc:
              name: {{ cluster.name }}-install-iso
              namespace: {{ namespace }}
          storage:
            resources:
              requests:
                storage: 5Gi{% endif %}
    template:
      metadata:
        annotations:
          vm.kubevirt.io/os: rhel9
          vm.kubevirt.io/workload: server
          k8s.v1.cni.cncf.io/networks: |
            [{"name":"virtualmachine-net","namespace":"{{ namespace }}","interface":"net1","interfaceRequest":"net1"}]
        labels:
          node: {{ vmname }}
          cluster: {{ cluster.name }}
          role: {{ role }}
      spec:{% if nsKey %}
        nodeSelector:
          {{ nsKey }}: {{ nsKey }}{{ vgNode }}{% endif %}
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                podAffinityTerm:
                  labelSelector:
                    matchExpressions:
                    - key: cluster
                      operator: In
                      values:
                      - {{ cluster.name }}
                    - key: role
                      operator: In
                      values:
                      - {{ role }}
                  topologyKey: "kubernetes.io/hostname"
        domain:
          memory:
            guest: {{ memory }}Gi
          cpu:
            cores: {{ cores }}
            sockets: {{ sockets }}
            threads: 1
          devices:
            disks:
              - bootOrder: 2
                disk:
                  bus: virtio
                name: rootdisk{% if hasIsoDisk %}
              - bootOrder: 3
                cdrom:
                  bus: sata
                name: {{ cluster.name }}-vm-install-iso{% endif %}{% for diskSize in dataDisks %}
              - disk:
                  bus: scsi
                name: datadisk-{{ loop.index0 }}{% endfor %}
            interfaces:
              - bridge: {}
                macAddress: {{ macaddr }}
                model: virtio
                name: {{ ifname }}
          resources:
            overcommitGuestOverhead: true
            requests:
              memory: {{ (memory / 2) | int }}Gi
              cpu: 2
            limits:
              memory: {{ memory }}Gi
              cpu: {{ cores * sockets }}
        evictionStrategy: None
        networks:
          - multus:
              networkName: {{ namespace }}/virtualmachine-net
            name: {{ ifname }}
        terminationGracePeriodSeconds: 180
        volumes:
          - name: rootdisk
            persistentVolumeClaim:
              claimName: {{ vmname }}{% if hasIsoDisk %}
          - name: {{ cluster.name }}-vm-install-iso
            dataVolume:
              name: {{ cluster.name }}-vm-install-iso{% endif %}{% for diskSize in dataDisks %}
          - name: datadisk-{{ loop.index0 }}
            persistentVolumeClaim:
              claimName: {{ vmname }}-data-{{ loop.index0 }}{% endfor %}
{% endfor %}
