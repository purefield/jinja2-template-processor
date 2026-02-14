{%- set argo = plugins.operators.argocd -%}
{%- set argoEnabled = argo.enabled | default(true) -%}
{%- set argoRbac = argo.rbac | default({}) -%}
{%- set argoRepo = argo.repo | default({}) -%}
{%- set argoRepoRes = argoRepo.resources | default({}) -%}
{%- if argoEnabled -%}
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-gitops-operator
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-gitops-operator
  namespace: openshift-gitops-operator
spec: {}
---
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
---
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
{{ (argoRbac.policy | default("g, system:cluster-admins, role:admin")) | indent(6, true) }}
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
        memory: 512Mi{% if argo.notifications is defined and not argo.notifications %}
  notifications:
    enabled: false{% endif %}
{%- if argo.bootstrap is defined and argo.bootstrap.repoURL is defined %}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-bootstrap
  namespace: openshift-gitops
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ argo.bootstrap.repoURL }}
    path: {{ argo.bootstrap.path | default(".") }}
    targetRevision: {{ argo.bootstrap.targetRevision | default("HEAD") }}
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ argo.bootstrap.namespace | default("openshift-gitops") }}{% if argo.bootstrap.autoSync | default(true) %}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true{% endif %}
{%- endif %}
{%- endif -%}
