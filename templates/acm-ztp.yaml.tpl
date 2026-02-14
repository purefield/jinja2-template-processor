{#- @meta
name: acm-ztp.yaml
description: ACM Zero Touch Provisioning manifests (InfraEnv, ClusterDeployment, NMState)
type: clusterfile
category: acm
platforms:
  - baremetal
  - kubevirt
requires:
  - account.pullSecret
  - cluster.name
  - cluster.sshKeys
  - network.domain
  - hosts.<hostname>.bmc
  - hosts.<hostname>.network
relatedTemplates:
  - acm-clusterimageset.yaml.tpl
  - acm-capi-m3.yaml.tpl
  - acm-asc.yaml.tpl
  - acm-creds.yaml.tpl
docs: https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.11/html/clusters/cluster_mce_overview#ztp-intro
-#}
{%- set imageArch = cluster.arch | default("x86_64", true) -%}
{%- set majorMinor = cluster.version.split('.')[:2] | join('.') -%}
{%- set controlCount = hosts.values() | selectattr('role', 'equalto', 'control') | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker')  | list | length -%}
{%- set enableTPM = cluster.tpm | default(false) -%}
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
- kind: Secret
  apiVersion: v1
  metadata:
    name: pullsecret-{{ cluster.name }}
    namespace: {{ cluster.name }}
    labels:
      agent-install.openshift.io/watch: "true"
      cluster.open-cluster-management.io/backup: "true"
  type: kubernetes.io/dockerconfigjson
  stringData:
    .dockerconfigjson: '{{load_file(account.pullSecret)}}'
- kind: AgentClusterInstall
  apiVersion: extensions.hive.openshift.io/v1beta1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
    labels:
      cluster-name: {{ cluster.name }}
  spec:{%- if network.proxy %}
    proxy: {{ network.proxy }}{% endif %}
    clusterDeploymentRef:
      name: {{ cluster.name }}
    imageSetRef:
      name: img{{ cluster.version }}-{{ cluster.arch | default("x86_64", true) | replace("_", "-") }}-appsub{% if cluster.mirrors %}
    mirrorRegistryRef:
      name: mirror-registries-{{ cluster.name }}
      namespace: multicluster-engine{% endif %}
    platformType: {% if controlCount > 1 %}BareMetal
    apiVIPs: {{ network.primary.vips.api }}
    ingressVIPs: {{ network.primary.vips.apps }}{% else %}None{% endif %}
    networking:
      userManagedNetworking: {{ false if controlCount > 1 else true }}
      networkType: {{ network.primary.type|default("OVNKubernetes", true) }}
      clusterNetwork:
        - cidr: {{ network.cluster.subnet }}
          hostPrefix: {{ network.cluster.hostPrefix|default(23, true) }}
      machineNetwork:
        - cidr: {{ network.primary.subnet }}
      serviceNetwork:
      - {{ network.service.subnet }}
    provisionRequirements:
      controlPlaneAgents: {{ controlCount }}
      workerAgents: {{ workerCount }}
    sshPublicKey: '{{load_file(cluster.sshKeys|first)|safe}}'{% if cluster.manifests or cluster.mirrors or enableTPM %}
    manifestsConfigMapRef:
      name: extraclustermanifests{% endif %}{% if cluster.mirrors %}
- kind: ConfigMap
  apiVersion: v1
  metadata:
    name: mirror-registries-{{ cluster.name }}
    namespace: multicluster-engine
    labels:
      app: assisted-service
  data:{% if network.trustBundle %}
    ca-bundle.crt: |
{{ load_file(network.trustBundle)|safe|indent(6,true) }}{% endif %}
    registries.conf: |{%- set registries %}{% include "includes/registries.conf.tpl" %}{% endset %}
{{ registries | indent(6,true) }}{% endif %}{% if cluster.manifests or cluster.mirrors or enableTPM %}
- kind: ConfigMap
  apiVersion: v1
  metadata:
    name: extraclustermanifests
    namespace: {{ cluster.name }}
  data:{% if cluster.manifests %}{% for manifest in cluster.manifests %}
    99-{{ manifest.name }}.yaml: |
{{ load_file(manifest.file )|safe|indent(8,true) }}{% endfor %}{% endif %}{% if enableTPM %}{%- set tpmManifest %}{% include "includes/tpm-disk-encryption.yaml.tpl" %}{% endset %}
    99-tpm-disk-encryption.yaml: |
{{ tpmManifest | indent(8, true) }}{% endif %}{% if cluster.mirrors %}{%- set sources %}{% include "includes/imageContentSource.yaml.tpl" %}{% endset %}
    99-image-digest-mirror-set.yaml: |
      kind: ImageDigestMirrorSet
      apiVersion: config.openshift.io/v1
      metadata:
        name: mirror-registries
      spec:
        imageDigestMirrors:
{{ sources | indent(10, true)}}
    99-image-tag-mirror-set.yaml: |
      kind: ImageTagMirrorSet
      apiVersion: config.openshift.io/v1
      metadata:
        name: mirror-registries
      spec:
        imageTagMirrors:
{{ sources | indent(10, true)}}{% endif %}{% endif %}
- kind: ClusterDeployment
  apiVersion: hive.openshift.io/v1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
    labels:
      cluster.open-cluster-management.io/clusterset: default
      hive.openshift.io/cluster-platform: agent-baremetal
    annotations:
      agentBareMetal-cpuArchitecture: x86_64
      agentclusterinstalls.extensions.hive.openshift.io/location: {{ cluster.location }}
  spec:
    clusterName: {{ cluster.name }}
    baseDomain: {{ network.domain }}
    clusterInstallRef:
      version: v1beta1
      kind: AgentClusterInstall
      name: {{ cluster.name }}
      group: extensions.hive.openshift.io
    controlPlaneConfig:
      servingCertificates: {}
    platform:
      agentBareMetal: 
        agentSelector:
          matchLabels:
            cluster-name: "{{ cluster.name }}"
    pullSecretRef:
      name: pullsecret-{{ cluster.name }}
- kind: KlusterletAddonConfig
  apiVersion: agent.open-cluster-management.io/v1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
  spec:
    applicationManager:
      argocdCluster: false
      enabled: true
    certPolicyController:
      enabled: true
    clusterLabels:
      name: {{ cluster.name }}
      cloud: Baremetal
      vendor: OpenShift
    clusterName: {{ cluster.name }}
    clusterNamespace: {{ cluster.name }}
    iamPolicyController:
      enabled: true
    policyController:
      enabled: true
    searchCollector:
      enabled: true
- kind: ManagedCluster
  apiVersion: cluster.open-cluster-management.io/v1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
    labels:
      name: {{ cluster.name }}
      cloud: BareMetal
      vendor: OpenShift
      location: {{ cluster.location }}
  spec:
    hubAcceptsClient: true
    leaseDurationSeconds: 60
# https://nmstate.io/examples.html
# https://access.redhat.com/solutions/7011711{% for name,host in hosts.items() %}
- apiVersion: agent-install.openshift.io/v1beta1
  kind: NMStateConfig
  metadata:
    labels:
      agent-install.openshift.io/bmh: {{ name }}
      infraenvs.agent-install.openshift.io: {{ cluster.name }}
    name: {{ name }}-nmstate
    namespace: {{ cluster.name }}
  spec:
    config: {%- set nmstate %}{% include "includes/nmstate.yaml.tpl" %}{% endset %}
{{ nmstate | indent(4,true) }}{% if host.bmc %}
- apiVersion: v1
  stringData:
    username: '{{ host.bmc.username }}'
    password: '{{load_file(host.bmc.password)}}'
  kind: Secret
  metadata:
    name: bmc-secret-{{ name }}
    namespace: {{ cluster.name }}
    labels:
      environment.metal3.io: baremetal
  type: Opaque{% endif %}
- apiVersion: metal3.io/v1alpha1
  kind: BareMetalHost
  metadata:
    annotations:
      bmac.agent-install.openshift.io/hostname: {{ name }} 
      bmac.agent-install.openshift.io/role: {{ 'master' if host.role == 'control' else 'worker' }}
      inspect.metal3.io: disabled
    labels:
      infraenvs.agent-install.openshift.io: {{ cluster.name }}
    name: {{ name }}
    namespace: {{ cluster.name }}
  spec:
    rootDeviceHints:  {{ host.storage.os }}
    automatedCleaningMode: metadata{% if host.bmc %}{%- set bmc %}{% include "includes/bmc.yaml.tpl" %}{% endset %}
    bmc:
{{ bmc | indent(6, true) }}{% endif %}{% set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first %}
    bootMACAddress: {{ bootNic.macAddress }}
    online: true
    customDeploy:
      method: start_assisted_install{% endfor %}
- kind: InfraEnv
  apiVersion: agent-install.openshift.io/v1beta1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
    labels:
      agentclusterinstalls.extensions.hive.openshift.io/location: {{ cluster.location }}
      networkType: static
    annotations:{% if account.bmc %}
      infraenv.agent-install.openshift.io/enable-ironic-agent: "true"{% endif %}
  spec:{%- if network.proxy %}
    proxy: {{ network.proxy }}{% endif %}{% if network.trustBundle %}
    additionalTrustBundle: |
{{ load_file(network.trustBundle)|safe|indent(6,true) }}{% endif %}
    additionalNTPSources: {{ network.ntpservers }}
    agentLabels:
      agentclusterinstalls.extensions.hive.openshift.io/location: {{ cluster.location }}
    cpuArchitecture: x86_64
    ipxeScriptType: DiscoveryImageAlways
    imageType: full-iso
    nmStateConfigLabelSelector:
      matchLabels:
        infraenvs.agent-install.openshift.io: {{ cluster.name }}
    pullSecretRef:
      name: pullsecret-{{ cluster.name }}
    sshAuthorizedKey: '{{load_file(cluster.sshKeys|first)|safe}}'
    clusterRef:
      name: {{ cluster.name }}
      namespace: {{ cluster.name }}{% if cluster.mirrors %}
    mirrorRegistryRef:
      name: mirror-registries-{{ cluster.name }}
      namespace: multicluster-engine{% endif %}
    agentLabelSelector:
      matchLabels:
        cluster-name: {{ cluster.name }}
- kind: ManifestWork
  apiVersion: work.open-cluster-management.io/v1
  metadata:
    name: poc-banner
    namespace: {{ cluster.name }}
  spec:
    workload:
      manifests:
        - apiVersion: console.openshift.io/v1
          kind: ConsoleNotification
          metadata:
            name: poc-banner
          spec:
            text: "This is a Proof of Concept and not for production use"
            location: BannerTop
            color: "#fff"
            backgroundColor: "#e00"
- kind: ServiceAccount
  apiVersion: v1
  metadata:
    name: os-images-sync
    namespace: {{ cluster.name }}
- kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: os-images-sync-{{ cluster.name }}
  subjects:
    - kind: ServiceAccount
      name: os-images-sync
      namespace: {{ cluster.name }}
  roleRef:
    kind: ClusterRole
    name: os-images-sync
    apiGroup: rbac.authorization.k8s.io
- kind: Job
  apiVersion: batch/v1
  metadata:
    name: os-images-sync
    namespace: {{ cluster.name }}
  spec:
    ttlSecondsAfterFinished: 300
    backoffLimit: 3
    template:
      spec:
        serviceAccountName: os-images-sync
        restartPolicy: Never
        containers:
          - name: sync
            image: registry.redhat.io/openshift4/ose-cli-rhel9:latest
            command:
              - /bin/sh
              - -c
              - |
                set -e
                VERSION="{{ cluster.version }}"
                EXISTS=$(oc get agentserviceconfig agent \
                  -o go-template='{% raw %}{{range .spec.osImages}}{{if eq .version "{% endraw %}'"$VERSION"'{% raw %}"}}found{{end}}{{end}}{% endraw %}')
                if [ "$EXISTS" = "found" ]; then
                  echo "osImage for $VERSION already present, skipping"
                  exit 0
                fi
                oc patch agentserviceconfig agent --type json \
                  -p '[{"op":"add","path":"/spec/osImages/-","value":{"openshiftVersion":"{{ majorMinor }}","version":"{{ cluster.version }}","cpuArchitecture":"{{ imageArch }}","url":"https://mirror.openshift.com/pub/openshift-v4/{{ imageArch }}/dependencies/rhcos/{{ majorMinor }}/latest/rhcos-live-iso.{{ imageArch }}.iso","rootFSUrl":"https://mirror.openshift.com/pub/openshift-v4/{{ imageArch }}/dependencies/rhcos/{{ majorMinor }}/latest/rhcos-live-rootfs.{{ imageArch }}.img"}}]'
                echo "Added osImage for $VERSION"
