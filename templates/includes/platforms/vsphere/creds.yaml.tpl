{# vSphere CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_vsphere/installing-vsphere-installer-provisioned-customizations.html #}
{% set vsphere = plugins.vsphere %}
{% set vcenter = vsphere.vcenter %}
apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:
- apiVersion: v1
  kind: Secret
  metadata:
    name: vsphere-creds
    namespace: kube-system
  type: Opaque
  stringData:
    {{ vcenter.server }}.username: {{ vcenter.username }}
    {{ vcenter.server }}.password: {{ load_file(vcenter.password) | trim }}
- apiVersion: v1
  kind: Secret
  metadata:
    name: vsphere-cloud-credentials
    namespace: openshift-cloud-controller-manager
  type: Opaque
  stringData:
    {{ vcenter.server }}.username: {{ vcenter.username }}
    {{ vcenter.server }}.password: {{ load_file(vcenter.password) | trim }}
