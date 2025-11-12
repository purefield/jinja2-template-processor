{%- set controlCount = hosts.values() | selectattr('role', 'equalto', 'control') | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker')  | list | length -%}
apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:
- kind: Namespace
  apiVersion: v1
  metadata:
    name: {{ cluster.name }}
  spec: {}
- kind: Cluster
  apiVersion: cluster.x-k8s.io/v1beta1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
  spec:
    clusterNetwork:
      pods:
        cidrBlocks:
          - 172.18.0.0/20
      services:
        cidrBlocks:
          - 10.96.0.0/12
    controlPlaneRef: 
      apiVersion: controlplane.cluster.x-k8s.io/v1alpha2
      kind: OpenshiftAssistedControlPlane
      name:  {{ cluster.name }}
      namespace: {{ cluster.name }}
    infrastructureRef: 
      apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
      kind: Metal3Cluster
      name: {{ cluster.name }}
      namespace: {{ cluster.name }}
- kind: OpenshiftAssistedControlPlane
  apiVersion: controlplane.cluster.x-k8s.io/v1alpha2
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
    annotations: {}
      #cluster.x-k8s.io/release-image-repository-override: registry.ci.openshift.org/ocp/release
  spec:
    openshiftAssistedConfigSpec:
      pullSecretRef:
        name: pullsecret-{{ cluster.name }}
      sshAuthorizedKey: '{{load_file(cluster.sshKeys|first)|safe}}'
      nodeRegistration:
        kubeletExtraLabels:
          - 'metal3.io/uuid="${METADATA_UUID}"'
      nmStateConfigLabelSelector: 
        matchLabels:
          role: controller
    distributionVersion: 4.19.10
    config:
      apiVIPs:
      - 172.21.0.201
      ingressVIPs:
      - 172.21.0.200
      baseDomain: {{ network.domain }}
      pullSecretRef:
        name: pullsecret-{{ cluster.name }}
      sshAuthorizedKey: '{{load_file(cluster.sshKeys|first)|safe}}'
    machineTemplate:
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: Metal3MachineTemplate
        name: {{ cluster.name }}-master
        namespace: {{ cluster.name }}
    replicas: 3
- kind: Secret
  apiVersion: v1
  metadata:
    name: pullsecret-{{ cluster.name }}
    namespace: {{ cluster.name }}
  type: kubernetes.io/dockerconfigjson
  stringData:
    .dockerconfigjson: '{{load_file(account.pullSecret)}}'
- kind: Metal3Cluster
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
  spec:
    controlPlaneEndpoint:
      host: {{ cluster.name }}.{{ network.domain }}
      port: 6443
    noCloudProvider: true
- kind: Metal3MachineTemplate
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
    name: {{ cluster.name }}-master
    namespace: {{ cluster.name }}
  spec:
    nodeReuse: false
    template:
      spec:
        hostSelector:
          matchLabels:
            role: controller
        automatedCleaningMode: metadata
        dataTemplate:
          name: {{ cluster.name }}-machine-template-master
        customDeploy:
          method: install_coreos
- kind: Metal3DataTemplate
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
     name: {{ cluster.name }}-machine-template-master
     namespace: {{ cluster.name }}
  spec:
     clusterName: {{ cluster.name }}
{% for name,host in hosts.items() %}
- kind: Secret
  apiVersion: v1
  metadata:
    name: {{ name }}-nmstate
    namespace: {{ cluster.name }}
  type: Opaque
  data:
    nmstate: {% set nmstate %}{% include "includes/nmstate.yaml.tpl" %}{% endset -%}
     {{ nmstate | base64encode }}{% if host.bmc %}
- kind: Secret
  apiVersion: v1
  stringData:
    username: '{{ host.bmc.username }}'
    password: '{{load_file(host.bmc.password)}}'
  metadata:
    name: bmc-secret-{{ name }}
    namespace: {{ cluster.name }}
    labels:
      environment.metal3.io: baremetal
  type: Opaque{% endif %}
- kind: BareMetalHost
  apiVersion: metal3.io/v1alpha1
  metadata:
    annotations:
      inspect.metal3.io: disabled
    labels:
      node: {{ name }} 
      role: {{ 'master' if host.role == 'control' else 'worker' }}
    name: {{ name }}
    namespace: {{ cluster.name }}
  spec:
    preprovisioningNetworkDataName: {{ name }}-nmstate
    rootDeviceHints:  {{ host.storage.os }}
    automatedCleaningMode: metadata{% if host.bmc %}{%- set bmc %}{% include "includes/bmc.yaml.tpl" %}{% endset %}
    bmc:
{{ bmc | indent(6, true) }}{% endif %}{% set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first %}
    bootMACAddress: {{ bootNic.macAddress }}
    online: false{%- endfor %}
