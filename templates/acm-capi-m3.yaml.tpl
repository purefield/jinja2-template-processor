{#- https://github.com/openshift-assisted/cluster-api-provider-openshift-assisted -#}
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
          - {{ network.cluster.subnet }}
      services:
        cidrBlocks:
          - {{ network.service.subnet }}
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
    annotations: 
      controlplane.cluster.x-k8s.io/install-config-override: |
        { "networking": { "machineNetwork": [ {"cidr": "{{ network.primary.subnet }}"} ],
                          "clusterNetwork": [ {"cidr": "{{ network.cluster.subnet }}", "hostPrefix": {{ network.cluster.hostPrefix|default(23, true) }}} ] },
          "compute": [ { "name": "worker", "replicas": 3 } ] }
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
    distributionVersion: {{ cluster.version }}
    config:{% if controlCount > 1 %}
      apiVIPs: {{ network.primary.vips.api }}
      ingressVIPs: {{ network.primary.vips.apps }}{% endif %}
      baseDomain: {{ network.domain }}
      pullSecretRef:
        name: pullsecret-{{ cluster.name }}
      sshAuthorizedKey: '{{load_file(cluster.sshKeys|first)|safe}}'
    machineTemplate:
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: Metal3MachineTemplate
        name: {{ cluster.name }}-controller
        namespace: {{ cluster.name }}
    replicas: {{ controlCount }}
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
    name: {{ cluster.name }}-controller
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
          name: {{ cluster.name }}-machine-template-controller
        image:
          format: qcow2
          checksumType: sha256
          checksum: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/sha256sum.txt
          url: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/rhcos-4.19.10-x86_64-nutanix.x86_64.qcow2
- kind: Metal3DataTemplate
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
     name: {{ cluster.name }}-machine-template-controller
     namespace: {{ cluster.name }}
  spec:
     clusterName: {{ cluster.name }}
{% for name,host in hosts.items() %}{% set shortname=name.split('.')[0]%}
- kind: Secret
  apiVersion: v1
  metadata:
    name: {{ shortname }}-provisioning-nmstate
    namespace: {{ cluster.name }}
  type: Opaque
  data:
    nmstate: {% set nmstate %}{% include "includes/nmstate.config.yaml.tpl" %}{% endset -%}
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
- kind: NMStateConfig
  apiVersion: agent-install.openshift.io/v1beta1
  metadata:
    labels:
      node: {{ shortname }}
      role: {{ 'controller' if host.role == 'control' else 'worker' }}
    name: {{ shortname }}-nmstate
    namespace: {{ cluster.name }}
  spec:
    config: {%- set nmstate %}{% include "includes/nmstate.yaml.tpl" %}{% endset %}
{{ nmstate | indent(4,true) }}
- kind: BareMetalHost
  apiVersion: metal3.io/v1alpha1
  metadata:
    annotations:
      inspect.metal3.io: disabled
    labels:
      node: {{ shortname }} 
      role: {{ 'controller' if host.role == 'control' else 'worker' }}
    name: {{ name }}
    namespace: {{ cluster.name }}
  spec:
    preprovisioningNetworkDataName: {{ shortname }}-provisioning-nmstate
    rootDeviceHints:  {{ host.storage.os }}
    automatedCleaningMode: metadata{% if host.bmc %}{%- set bmc %}{% include "includes/bmc.yaml.tpl" %}{% endset %}
    bmc:
{{ bmc | indent(6, true) }}{% endif %}{% set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first %}
    bootMACAddress: {{ bootNic.macAddress }}
    online: false
{% endfor %}
