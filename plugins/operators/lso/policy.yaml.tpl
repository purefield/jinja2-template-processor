{%- set lso = plugins.operators.lso -%}
{%- set lsoEnabled = lso.enabled | default(true) -%}
{%- set dis = lso.deviceInclusionSpec | default({}) -%}
{%- set ns = lso.nodeSelector | default({"cluster.ocs.openshift.io/openshift-storage": ""}) -%}
{%- if lsoEnabled %}
- kind: Policy
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-lso
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
            name: lso-subscription
          spec:
            remediationAction: enforce
            severity: high
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: v1
                  kind: Namespace
                  metadata:
                    name: openshift-local-storage
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1
                  kind: OperatorGroup
                  metadata:
                    name: local-storage-operatorgroup
                    namespace: openshift-local-storage
                  spec:
                    targetNamespaces:
                      - openshift-local-storage
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1alpha1
                  kind: Subscription
                  metadata:
                    name: local-storage-operator
                    namespace: openshift-local-storage
                  spec:
                    channel: {{ lso.channel | default("stable") }}
                    installPlanApproval: {{ lso.approval | default("Automatic") }}
                    name: local-storage-operator
                    source: {{ lso.source | default("redhat-operators") }}
                    sourceNamespace: openshift-marketplace
      - extraDependencies:
          - apiVersion: policy.open-cluster-management.io/v1
            kind: ConfigurationPolicy
            name: lso-subscription
            compliance: Compliant
        objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: lso-operator-ready
          spec:
            remediationAction: inform
            severity: medium
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: apiextensions.k8s.io/v1
                  kind: CustomResourceDefinition
                  metadata:
                    name: localvolumesets.local.openshift.io
      - extraDependencies:
          - apiVersion: policy.open-cluster-management.io/v1
            kind: ConfigurationPolicy
            name: lso-operator-ready
            compliance: Compliant
        objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: lso-localvolumeset
          spec:
            remediationAction: enforce
            severity: medium
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: local.openshift.io/v1alpha1
                  kind: LocalVolumeSet
                  metadata:
                    name: local-block
                    namespace: openshift-local-storage
                  spec:
                    storageClassName: {{ lso.storageClassName | default("local-block") }}
                    volumeMode: {{ lso.volumeMode | default("Block") }}{% if lso.volumeMode | default("Block") == "Filesystem" %}
                    fsType: {{ lso.fsType | default("xfs") }}{% endif %}
                    nodeSelector:
                      nodeSelectorTerms:
                        - matchExpressions:{% for key, val in ns.items() %}
                            - key: {{ key }}
                              operator: In
                              values:
                                - "{{ val }}"{% endfor %}
                    deviceInclusionSpec:
                      deviceTypes:{% for dt in dis.deviceTypes | default(["disk"]) %}
                        - {{ dt }}{% endfor %}{% if dis.minSize is defined %}
                      minSize: {{ dis.minSize }}{% endif %}{% if dis.maxSize is defined %}
                      maxSize: {{ dis.maxSize }}{% endif %}
- kind: PlacementBinding
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-lso
    namespace: {{ cluster.name }}
  placementRef:
    name: {{ cluster.name }}
    kind: Placement
    apiGroup: cluster.open-cluster-management.io
  subjects:
    - name: operator-lso
      kind: Policy
      apiGroup: policy.open-cluster-management.io
{%- endif -%}
