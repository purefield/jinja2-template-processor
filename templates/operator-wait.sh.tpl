{#- Operator wait script: generates diagnostic checks for ACM Policy-delivered operators -#}
{#- Usage: process.py clusterfile operator-wait.sh.tpl | bash                            -#}
{#- Requires: format.sh sourced (provides __, oo)                                       -#}
{%- set ops = plugins.operators | default({}) -%}
{%- set odf = ops.odf | default({}) -%}
{%- set odfEnabled = odf.enabled | default(true) if 'odf' in ops else false -%}
{%- set lvm = ops.lvm | default({}) -%}
{%- set lvmEnabled = lvm.enabled | default(true) if 'lvm' in ops else false -%}
{%- set argo = ops.argocd | default({}) -%}
{%- set argoEnabled = argo.enabled | default(true) if 'argocd' in ops else false -%}
{%- set cm = ops['cert-manager'] | default({}) -%}
{%- set cmEnabled = cm.enabled | default(true) if 'cert-manager' in ops else false -%}
{%- set es = ops['external-secrets'] | default({}) -%}
{%- set esEnabled = es.enabled | default(true) if 'external-secrets' in ops else false -%}
__ "Operator delivery status for {{ cluster.name }}" 2{% if odfEnabled %}
__ "ODF Operator" 3
__ "Namespace: openshift-storage" 4
oo 1 "oc get namespace openshift-storage -o name --ignore-not-found 2>/dev/null | wc -l"
__ "Subscription: odf-operator" 4
oo 1 "oc get subscription.operators.coreos.com odf-operator -n openshift-storage -o name --ignore-not-found 2>/dev/null | wc -l"
__ "CSV phase (waiting for Succeeded)" 4
oo 1 "oc get csv -n openshift-storage -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c Succeeded"
__ "CRD: storageclusters.ocs.openshift.io" 4
oo 1 "oc get crd storageclusters.ocs.openshift.io -o name 2>/dev/null | wc -l"
__ "StorageCluster: Ready" 4
oo 1 "oc get storagecluster -n openshift-storage ocs-storagecluster -o=jsonpath='{.status.phase}' --ignore-not-found 2>/dev/null | grep -c Ready"{% endif %}{% if lvmEnabled %}
__ "LVM Operator" 3
__ "Namespace: openshift-storage" 4
oo 1 "oc get namespace openshift-storage -o name --ignore-not-found 2>/dev/null | wc -l"
__ "Subscription: lvms-operator" 4
oo 1 "oc get subscription.operators.coreos.com lvms-operator -n openshift-storage -o name --ignore-not-found 2>/dev/null | wc -l"
__ "CRD: lvmclusters.lvm.topolvm.io" 4
oo 1 "oc get crd lvmclusters.lvm.topolvm.io -o name 2>/dev/null | wc -l"
__ "LVMCluster: Ready" 4
oo 1 "oc get lvmcluster -n openshift-storage lvmcluster -o=jsonpath='{.status.state}' --ignore-not-found 2>/dev/null | grep -c Ready"{% endif %}{% if argoEnabled %}
__ "ArgoCD Operator" 3
__ "Namespace: openshift-gitops-operator" 4
oo 1 "oc get namespace openshift-gitops-operator -o name --ignore-not-found 2>/dev/null | wc -l"
__ "Subscription: openshift-gitops-operator" 4
oo 1 "oc get subscription.operators.coreos.com openshift-gitops-operator -n openshift-gitops-operator -o name --ignore-not-found 2>/dev/null | wc -l"
__ "CRD: argocds.argoproj.io" 4
oo 1 "oc get crd argocds.argoproj.io -o name 2>/dev/null | wc -l"
__ "ArgoCD instance: Running" 4
oo 1 "oc get argocd openshift-gitops -n openshift-gitops -o=jsonpath='{.status.phase}' --ignore-not-found 2>/dev/null | grep -c Available"{% endif %}{% if cmEnabled %}
__ "cert-manager Operator" 3
__ "Subscription: openshift-cert-manager-operator" 4
oo 1 "oc get subscription.operators.coreos.com openshift-cert-manager-operator -n cert-manager-operator -o name --ignore-not-found 2>/dev/null | wc -l"
__ "CSV phase (waiting for Succeeded)" 4
oo 1 "oc get csv -n cert-manager-operator -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c Succeeded"{% endif %}{% if esEnabled %}
__ "External Secrets Operator" 3
__ "Subscription: external-secrets-operator" 4
oo 1 "oc get subscription.operators.coreos.com external-secrets-operator -n openshift-operators -o name --ignore-not-found 2>/dev/null | wc -l"
__ "CSV phase (waiting for Succeeded)" 4
oo 1 "oc get csv -n openshift-operators -l operators.coreos.com/external-secrets-operator.openshift-operators -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c Succeeded"{% endif %}
__ "All enabled operators ready" ok
