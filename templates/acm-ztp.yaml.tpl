{%- set controlCount = hosts.values() | selectattr('role', 'equalto', 'control') | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker')  | list | length -%}
apiVersion: v1

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
  spec:
    clusterDeploymentRef:
      name: virt
    imageSetRef:
      name: img{{ cluster.version }}-x86-64-appsub
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
    sshPublicKey: '{{load_file(cluster.sshKey)|safe}}'
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
# https://access.redhat.com/solutions/7011711
{%- set enabledFalse='{"enabled":false}' %}{% for name,host in hosts.items() -%}
{%- set ipv4={"enabled":true,"address":[{"ip":host.network.primary.address,"prefix-length":network.primary.subnet.split('/')[1]|int}],"dhcp":false} %}
- apiVersion: agent-install.openshift.io/v1beta1
  kind: NMStateConfig
  metadata:
    labels:
      agent-install.openshift.io/bmh: {{ name }}
      infraenvs.agent-install.openshift.io: {{ cluster.name }}
    name: {{ name }}-nmstate
    namespace: {{ cluster.name }}
  spec:
    config:
      interfaces:{%- if network.primary.bond %}{% set ifName="bond0" %}
        - type: bond
          name: {{ ifName }}{% if network.primary.mtu %}
          mtu: {{ network.primary.mtu }}{% endif %}
          state: up
          ipv4: {{ enabledFalse if network.primary.vlan else ipv4 }}
          ipv6: {{ enabledFalse }}
          link-aggregation:
            mode: {{ network.primary.bond }}
            options:
              miimon: "150"
            port: {{ host.network.primary.ports }}{% else %}
        - type: ethernet
          name: {{ ifName }}{% if network.primary.mtu %}
          mtu: {{ network.primary.mtu }}{% endif %}
          state: up
          ipv4: {{ enabledFalse if network.primary.vlan else ipv4 }}
          ipv6: {{ enabledFalse }}{% endif %}{%- if network.primary.vlan %}
        - type: vlan
          name: {{ ifName ~ "." ~ network.primary.vlan }}
          ipv4: {{ ipv4 }}
          ipv6: {{ enabledFalse }}{% if network.primary.mtu %}
          mtu: {{ network.primary.mtu }}{% endif %}
          state: up
          vlan:
            base-iface: {{ ifName }}
            id: {{ network.primary.vlan }}{% set ifName=ifName ~ "." ~ network.primary.vlan %}{% endif %}
      dns-resolver:
        config:
          server: {{ network.nameservers }}{% if network.dnsResolver and network.dnsResolver.search %}
          search: {{ network.dnsResolver.search }}{% endif %}
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: {{ network.primary.gateway }}
            next-hop-interface: {{ ifName }}
            table-id: 254{% if host.bmc %}
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
    automatedCleaningMode: metadata{% if host.bmc %}
    bmc:
      address: {{ 'idrac-virtualmedia://'+host.bmc.address+'/redfish/v1/Systems/System.Embedded.1' if host.bmc.vendor == 'dell' else 'TODO' }}
      credentialsName: bmc-secret-{{ name }}
      disableCertificateVerification: true{% endif %}{% set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first %}
    bootMACAddress: {{ bootNic.macAddress }}
    online: true
    customDeploy:
      method: start_assisted_install{%- endfor %}
- kind: InfraEnv
  apiVersion: agent-install.openshift.io/v1beta1
  metadata:
    name: {{ cluster.name }}
    namespace: {{ cluster.name }}
    labels:
      agentclusterinstalls.extensions.hive.openshift.io/location: ola
      networkType: static
    annotations:{% if account.bmc %}
      infraenv.agent-install.openshift.io/enable-ironic-agent: "true"{% endif %}
  spec:
    additionalNTPSources: {{ network.ntpservers }}
    agentLabels:
      agentclusterinstalls.extensions.hive.openshift.io/location: {{ cluster.location }}
    cpuArchitecture: x86_64
    ipxeScriptType: DiscoveryImageAlways
    nmStateConfigLabelSelector:
      matchLabels:
        infraenvs.agent-install.openshift.io: {{ cluster.name }}
    pullSecretRef:
      name: pullsecret-{{ cluster.name }}
    sshAuthorizedKey: '{{load_file(cluster.sshKey)}}'
    clusterRef:
      name: {{ cluster.name }}
      namespace: {{ cluster.name }}
    agentLabelSelector:
      matchLabels:
        cluster-name: {{ cluster.name }}
kind: List
metadata:
  resourceVersion: ""
