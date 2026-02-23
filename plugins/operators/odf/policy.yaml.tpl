{%- set odf = plugins.operators.odf -%}
{%- set odfEnabled = odf.enabled | default(true) -%}
{%- set odfChannel = odf.channel | default("stable-" + cluster.version.split(".")[:2] | join(".")) -%}
{%- set sc = odf.storageCluster | default({}) -%}
{%- set _workers = [] -%}
{%- for hostname, host in hosts.items() if host.role | default('worker') == 'worker' -%}
{%- set _ = _workers.append(hostname) -%}
{%- endfor -%}
{%- set odf_nodes = _workers if _workers else hosts.keys() | list -%}
{%- if odfEnabled %}
- kind: Policy
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-odf
    namespace: {{ cluster.name }}
    annotations:
      policy.open-cluster-management.io/standards: NIST SP 800-53
      policy.open-cluster-management.io/categories: CM Configuration Management
      policy.open-cluster-management.io/controls: CM-2 Baseline Configuration
  spec:
    remediationAction: enforce
    disabled: false
    policy-templates:
      - objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: odf-node-labels
          spec:
            remediationAction: enforce
            severity: high
            object-templates:{% for node in odf_nodes %}
              - complianceType: musthave
                objectDefinition:
                  apiVersion: v1
                  kind: Node
                  metadata:
                    name: {{ node }}
                    labels:
                      cluster.ocs.openshift.io/openshift-storage: ""{% endfor %}
      - objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: odf-subscription
          spec:
            remediationAction: enforce
            severity: high
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: v1
                  kind: Namespace
                  metadata:
                    name: openshift-storage
                    labels:
                      openshift.io/cluster-monitoring: "true"
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1
                  kind: OperatorGroup
                  metadata:
                    name: openshift-storage-operatorgroup
                    namespace: openshift-storage
                  spec:
                    targetNamespaces:
                      - openshift-storage
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1alpha1
                  kind: Subscription
                  metadata:
                    name: odf-operator
                    namespace: openshift-storage
                  spec:
                    channel: {{ odfChannel }}
                    installPlanApproval: {{ odf.approval | default("Automatic") }}
                    name: odf-operator
                    source: {{ odf.source | default("redhat-operators") }}
                    sourceNamespace: openshift-marketplace
      - extraDependencies:
          - apiVersion: policy.open-cluster-management.io/v1
            kind: ConfigurationPolicy
            name: odf-subscription
            compliance: Compliant
        objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: odf-operator-ready
          spec:
            remediationAction: inform
            severity: medium
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: apiextensions.k8s.io/v1
                  kind: CustomResourceDefinition
                  metadata:
                    name: storageclusters.ocs.openshift.io
      - extraDependencies:
          - apiVersion: policy.open-cluster-management.io/v1
            kind: ConfigurationPolicy
            name: odf-operator-ready
            compliance: Compliant
          - apiVersion: policy.open-cluster-management.io/v1
            kind: ConfigurationPolicy
            name: odf-node-labels
            compliance: Compliant
        objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: odf-storagecluster
          spec:
            remediationAction: enforce
            severity: medium
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: ocs.openshift.io/v1
                  kind: StorageCluster
                  metadata:
                    name: {{ sc.name | default("ocs-storagecluster") }}
                    namespace: openshift-storage
                  spec:
                    monDataDirHostPath: {{ sc.monDataDirHostPath | default("/var/lib/rook") }}
                    storageDeviceSets:{% if sc.storageDeviceSets is defined %}{% for sds in sc.storageDeviceSets %}
                      - name: {{ sds.name | default("ocs-deviceset") }}
                        count: {{ sds.count | default(1) }}
                        replica: {{ sds.replica | default(3) }}
                        portable: true
                        dataPVCTemplate:
                          spec:
                            accessModes:
                              - ReadWriteOnce{% if sds.storageClassName is defined and sds.storageClassName %}
                            storageClassName: {{ sds.storageClassName }}{% endif %}
                            resources:
                              requests:
                                storage: {{ sds.storage | default("1Ti") }}
                            volumeMode: Block{% endfor %}{% else %}
                      - name: ocs-deviceset
                        count: 1
                        replica: 3
                        portable: true
                        dataPVCTemplate:
                          spec:
                            accessModes:
                              - ReadWriteOnce
                            resources:
                              requests:
                                storage: 1Ti
                            volumeMode: Block{% endif %}
- kind: PlacementBinding
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-odf
    namespace: {{ cluster.name }}
  placementRef:
    name: {{ cluster.name }}
    kind: Placement
    apiGroup: cluster.open-cluster-management.io
  subjects:
    - name: operator-odf
      kind: Policy
      apiGroup: policy.open-cluster-management.io
{%- endif -%}
