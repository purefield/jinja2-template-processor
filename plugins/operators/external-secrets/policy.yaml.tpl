{%- set es = plugins.operators['external-secrets'] -%}
{%- set esEnabled = es.enabled | default(true) -%}
{%- if esEnabled %}
- kind: Policy
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-external-secrets
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
            name: external-secrets-subscription
          spec:
            remediationAction: enforce
            severity: high
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1alpha1
                  kind: Subscription
                  metadata:
                    name: external-secrets-operator
                    namespace: openshift-operators
                  spec:
                    channel: {{ es.channel | default("stable-v1") }}
                    installPlanApproval: {{ es.approval | default("Automatic") }}
                    name: external-secrets-operator
                    source: {{ es.source | default("redhat-operators") }}
                    sourceNamespace: openshift-marketplace
- kind: PlacementBinding
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-external-secrets
    namespace: {{ cluster.name }}
  placementRef:
    name: {{ cluster.name }}
    kind: Placement
    apiGroup: cluster.open-cluster-management.io
  subjects:
    - name: operator-external-secrets
      kind: Policy
      apiGroup: policy.open-cluster-management.io
{%- endif -%}
