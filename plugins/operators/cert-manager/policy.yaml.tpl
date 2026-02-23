{%- set cm = plugins.operators['cert-manager'] -%}
{%- set cmEnabled = cm.enabled | default(true) -%}
{%- if cmEnabled %}
- kind: Policy
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-cert-manager
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
            name: cert-manager-subscription
          spec:
            remediationAction: enforce
            severity: high
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: v1
                  kind: Namespace
                  metadata:
                    name: cert-manager-operator
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1
                  kind: OperatorGroup
                  metadata:
                    name: cert-manager-operator
                    namespace: cert-manager-operator
                  spec:
                    targetNamespaces:
                      - cert-manager-operator
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1alpha1
                  kind: Subscription
                  metadata:
                    name: openshift-cert-manager-operator
                    namespace: cert-manager-operator
                  spec:
                    channel: {{ cm.channel | default("stable-v1") }}
                    installPlanApproval: {{ cm.approval | default("Automatic") }}
                    name: openshift-cert-manager-operator
                    source: {{ cm.source | default("redhat-operators") }}
                    sourceNamespace: openshift-marketplace
      - extraDependencies:
          - apiVersion: policy.open-cluster-management.io/v1
            kind: ConfigurationPolicy
            name: cert-manager-subscription
            compliance: Compliant
        objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: cert-manager-operator-ready
          spec:
            remediationAction: inform
            severity: medium
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: apiextensions.k8s.io/v1
                  kind: CustomResourceDefinition
                  metadata:
                    name: certmanagers.operator.openshift.io
- kind: PlacementBinding
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-cert-manager
    namespace: {{ cluster.name }}
  placementRef:
    name: {{ cluster.name }}
    kind: Placement
    apiGroup: cluster.open-cluster-management.io
  subjects:
    - name: operator-cert-manager
      kind: Policy
      apiGroup: policy.open-cluster-management.io
{%- endif -%}
