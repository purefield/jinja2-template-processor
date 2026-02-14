{%- set argo = plugins.operators.argocd -%}
{%- set argoEnabled = argo.enabled | default(true) -%}
{%- set argoRbac = argo.rbac | default({}) -%}
{%- set argoRepo = argo.repo | default({}) -%}
{%- set argoRepoRes = argoRepo.resources | default({}) -%}
{%- if argoEnabled %}
- kind: Policy
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-argocd
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
            name: argocd-subscription
          spec:
            remediationAction: enforce
            severity: high
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: v1
                  kind: Namespace
                  metadata:
                    name: openshift-gitops-operator
                    labels:
                      openshift.io/cluster-monitoring: "true"
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1
                  kind: OperatorGroup
                  metadata:
                    name: openshift-gitops-operator
                    namespace: openshift-gitops-operator
                  spec: {}
              - complianceType: musthave
                objectDefinition:
                  apiVersion: operators.coreos.com/v1alpha1
                  kind: Subscription
                  metadata:
                    name: openshift-gitops-operator
                    namespace: openshift-gitops-operator
                  spec:
                    channel: {{ argo.channel | default("latest") }}
                    installPlanApproval: {{ argo.approval | default("Automatic") }}
                    name: openshift-gitops-operator
                    source: {{ argo.source | default("redhat-operators") }}
                    sourceNamespace: openshift-marketplace
      - objectDefinition:
          apiVersion: policy.open-cluster-management.io/v1
          kind: ConfigurationPolicy
          metadata:
            name: argocd-instance
          spec:
            remediationAction: enforce
            severity: medium
            object-templates:
              - complianceType: musthave
                objectDefinition:
                  apiVersion: argoproj.io/v1beta1
                  kind: ArgoCD
                  metadata:
                    name: openshift-gitops
                    namespace: openshift-gitops
                  spec:
                    server:
                      autoscale:
                        enabled: false
                      grpc:
                        ingress:
                          enabled: false
                      ingress:
                        enabled: false
                      route:
                        enabled: true
                        tls:
                          termination: reencrypt
                    resourceExclusions: |
                      - apiGroups:
                          - tekton.dev
                        clusters:
                          - '*'
                        kinds:
                          - TaskRun
                          - PipelineRun
                    ha:
                      enabled: {{ argo.ha | default(false) | lower }}
                    rbac:
                      defaultPolicy: '{{ argoRbac.defaultPolicy | default("role:readonly") }}'
                      policy: |
{{ (argoRbac.policy | default("g, system:cluster-admins, role:admin")) | indent(24, true) }}
                      scopes: '{{ argoRbac.scopes | default("[groups]") }}'
                    repo:
                      resources:
                        limits:
                          cpu: '{{ argoRepoRes.cpu | default("1") }}'
                          memory: {{ argoRepoRes.memory | default("1Gi") }}
                        requests:
                          cpu: 250m
                          memory: 256Mi
                    applicationSet:
                      resources:
                        limits:
                          cpu: '2'
                          memory: 1Gi
                        requests:
                          cpu: 250m
                          memory: 512Mi
- kind: PlacementBinding
  apiVersion: policy.open-cluster-management.io/v1
  metadata:
    name: operator-argocd
    namespace: {{ cluster.name }}
  placementRef:
    name: {{ cluster.name }}
    kind: Placement
    apiGroup: cluster.open-cluster-management.io
  subjects:
    - name: operator-argocd
      kind: Policy
      apiGroup: policy.open-cluster-management.io
{%- endif -%}
