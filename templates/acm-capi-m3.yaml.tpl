{#- @meta
name: acm-capi-m3.yaml
description: ACM Cluster API with Metal3 provider for bare metal provisioning
type: clusterfile
category: acm
platforms:
  - baremetal
  - kubevirt
requires:
  - cluster.name
  - cluster.sshKeys
  - network.domain
  - hosts.<hostname>.bmc
  - hosts.<hostname>.network
relatedTemplates:
  - acm-clusterimageset.yaml.tpl
  - acm-ztp.yaml.tpl
  - acm-asc.yaml.tpl
  - acm-creds.yaml.tpl
docs: https://github.com/openshift-assisted/cluster-api-provider-openshift-assisted
-#}
{#- openshift-machine-api.metal3.metal3-ironic, kubevirt-redfish.kubevirt-redfish - logs -#}
{%- set imageArch = cluster.arch | default("x86_64", true) -%}
{%- set majorMinor = cluster.version.split('.')[:2] | join('.') -%}
{%- set enableTang = cluster.diskEncryption is defined and cluster.diskEncryption.type | default("none") == "tang" -%}
{%- set imageChecksum="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/sha256sum.txt" -%}
{%- set imageUrl="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/rhcos-4.19.10-x86_64-nutanix.x86_64.qcow2" -%}
{%- set imageUrl="" -%}
{%- set ignitionOverride='{"ignition":{"version":"3.1.0"},"passwd":{"users":[{"groups":["sudo"],"name":"core","passwordHash":"$6$f4/AcN1ComFGli0Z$CJ5GkVIc6H4ofkzfY5uml78bAjgMsoh2oRG.zDBca1DxR0ljGm/xllwYGZpj91u3Dev/VFO.C1HlzEOjldoIC."}]}}' -%}
{%- set enableDisconnected = cluster.disconnected | default(false) -%}
{%- set insecureMirrors = cluster.mirrors | default([]) | selectattr('insecure', 'defined') | selectattr('insecure') | list -%}
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
          "compute": [ { "name": "worker", "replicas": {{ workerCount }} } ] }
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
        automatedCleaningMode: disabled
        dataTemplate:
          name: {{ cluster.name }}-machine-template-controller{% if imageUrl %}
        image:
          format: qcow2
          checksumType: sha256
          checksum: {{ imageChecksum }}
          url: {{ imageUrl }}{% else %}
        customDeploy:
          method: install_coreos{% endif %}
- kind: Metal3DataTemplate
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
     name: {{ cluster.name }}-machine-template-controller
     namespace: {{ cluster.name }}
  spec:
    clusterName: {{ cluster.name }}{% if workerCount > 0 %}
- kind: Metal3MachineTemplate
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
    name: {{ cluster.name }}-worker
    namespace: {{ cluster.name }}
  spec:
    nodeReuse: false
    template:
      spec:
        hostSelector:
          matchLabels:
            role: worker
        automatedCleaningMode: disabled
        dataTemplate:
          name: {{ cluster.name }}-machine-template-worker{% if imageUrl %}
        image:
          format: qcow2
          checksumType: sha256
          checksum: {{ imageChecksum }}
          url: {{ imageUrl }}{% else %}
        customDeploy:
          method: install_coreos{% endif %}
- kind: Metal3DataTemplate
  apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
  metadata:
     name: {{ cluster.name }}-machine-template-worker
     namespace: {{ cluster.name }}
  spec:
     clusterName: {{ cluster.name }}
- kind: MachineDeployment
  apiVersion: cluster.x-k8s.io/v1beta1
  metadata:
    name: {{ cluster.name }}-worker
    namespace: {{ cluster.name }}
    labels:
      cluster.x-k8s.io/cluster-name: {{ cluster.name }}
  spec:
    clusterName: {{ cluster.name }}
    replicas: {{ workerCount }}
    selector:
      matchLabels:
        cluster.x-k8s.io/cluster-name: {{ cluster.name }}
    template:
      metadata:
        labels:
          cluster.x-k8s.io/cluster-name: {{ cluster.name }}
      spec:
        clusterName: {{ cluster.name }}
        bootstrap:
          configRef:
            name: {{ cluster.name }}-worker
            apiVersion: bootstrap.cluster.x-k8s.io/v1alpha1
            kind: OpenshiftAssistedConfigTemplate
        infrastructureRef:
          name: {{ cluster.name }}-worker
          apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
          kind: Metal3MachineTemplate
- kind: OpenshiftAssistedConfigTemplate
  apiVersion: bootstrap.cluster.x-k8s.io/v1alpha1
  metadata:
    name: {{ cluster.name }}-worker
    namespace: {{ cluster.name }}
    labels:
      cluster.x-k8s.io/cluster-name: {{ cluster.name }}
  spec:
    template:
      metadata:
        annotations:
          openshiftassistedconfig.cluster.x-k8s.io/discovery-ignition-override: '{{ ignitionOverride }}'
      spec:
        nodeRegistration:
          kubeletExtraLabels:
            - 'metal3.io/uuid="${METADATA_UUID}"'
        nmStateConfigLabelSelector:
          matchLabels:
            role: worker
        pullSecretRef:
          name: "pullsecret-{{ cluster.name }}"
        sshAuthorizedKey: '{{load_file(cluster.sshKeys|first)|safe}}'{% endif %}{% for name,host in hosts.items() %}{% set shortname=name.split('.')[0] %}
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
      inspect.metal3.io: {{ host.ironicInspect if host.ironicInspect is defined else "disabled" }}{% if host.ignitionConfigOverride is defined %}
      bmac.agent-install.openshift.io/ignition-config-overrides: '{{ host.ignitionConfigOverride }}'{% endif %}
    labels:
      node: {{ shortname }}
      role: {{ 'controller' if host.role == 'control' else 'worker' }}
    name: {{ name }}
    namespace: {{ cluster.name }}
  spec:
    preprovisioningNetworkDataName: {{ shortname }}-provisioning-nmstate
    rootDeviceHints:  {{ host.storage.os }}{% if host.bootMode is defined %}
    bootMode: {{ host.bootMode }}{% endif %}
    automatedCleaningMode: {{ host.automatedCleaningMode | default("disabled") }}{% if host.bmc %}{%- set bmc %}{% include "includes/bmc.yaml.tpl" %}{% endset %}
    bmc:
{{ bmc | indent(6, true) }}{% endif %}{% set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first %}
    bootMACAddress: {{ bootNic.macAddress }}
    online: false{% endfor %}
{%- set pocBanner %}{% include "includes/poc-banner-manifestwork.yaml.tpl" %}{% endset %}
{{ pocBanner }}{%- set insecureImageManifest %}
        - apiVersion: config.openshift.io/v1
          kind: Image
          metadata:
            name: cluster
          spec:
            registrySources:
              insecureRegistries:{% for mirror in insecureMirrors %}{% for location in mirror.mirrors %}
                - {{ location }}{% endfor %}{% endfor %}
{%- endset %}{% if enableDisconnected %}
- kind: ManifestWork
  apiVersion: work.open-cluster-management.io/v1
  metadata:
    name: disconnected-operatorhub
    namespace: {{ cluster.name }}
  spec:
    workload:
      manifests:
        - apiVersion: config.openshift.io/v1
          kind: OperatorHub
          metadata:
            name: cluster
          spec:
            disableAllDefaultSources: true{% if cluster.catalogSources is defined %}{% for catalog in cluster.catalogSources %}
        - apiVersion: operators.coreos.com/v1alpha1
          kind: CatalogSource
          metadata:
            name: {{ catalog.name }}
            namespace: openshift-marketplace
          spec:
            sourceType: grpc
            image: {{ catalog.image }}
            displayName: {{ catalog.displayName | default(catalog.name) }}
            publisher: {{ catalog.publisher | default("Custom") }}{% endfor %}{% endif %}{% if insecureMirrors %}
{{ insecureImageManifest }}{% endif %}{% endif %}{% if insecureMirrors and not enableDisconnected %}
- kind: ManifestWork
  apiVersion: work.open-cluster-management.io/v1
  metadata:
    name: insecure-registries
    namespace: {{ cluster.name }}
  spec:
    workload:
      manifests:
{{ insecureImageManifest }}{% endif %}
{%- set osImagesSync %}{% include "includes/os-images-sync.yaml.tpl" %}{% endset %}
{{ osImagesSync }}{% if plugins is defined and plugins.operators is defined %}
{%- set ops = plugins.operators -%}
{%- if ops.argocd is defined %}{%- set opPolicy %}{% include "operators/argocd/policy.yaml.tpl" %}{% endset %}
{{ opPolicy }}{% endif -%}
{%- if ops.lvm is defined %}{%- set opPolicy %}{% include "operators/lvm/policy.yaml.tpl" %}{% endset %}
{{ opPolicy }}{% endif -%}
{%- if ops.odf is defined %}{%- set opPolicy %}{% include "operators/odf/policy.yaml.tpl" %}{% endset %}
{{ opPolicy }}{% endif -%}
{%- if ops['cert-manager'] is defined %}{%- set opPolicy %}{% include "operators/cert-manager/policy.yaml.tpl" %}{% endset %}
{{ opPolicy }}{% endif -%}
{%- if ops['external-secrets'] is defined %}{%- set opPolicy %}{% include "operators/external-secrets/policy.yaml.tpl" %}{% endset %}
{{ opPolicy }}{% endif -%}
{% endif %}

