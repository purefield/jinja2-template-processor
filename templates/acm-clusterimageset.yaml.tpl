{#- @meta
name: acm-clusterimageset.yaml
description: ClusterImageSet for ACM/MCE cluster deployments (ZTP, CAPI+M3)
type: clusterfile
category: acm
platforms:
  - baremetal
  - none
requires:
  - cluster.version
relatedTemplates:
  - acm-ztp.yaml.tpl
  - acm-capi-m3.yaml.tpl
docs: https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.12/html/clusters/cluster_mce_overview#clusterimageset-cr
-#}
{%- set arch = cluster.arch | default("x86-64", true) -%}
{%- set imageArch = arch | replace("-", "_") -%}
{%- set quayMirrors = (cluster.mirrors | default([])) | selectattr('source', 'equalto', 'quay.io') | list -%}
{%- set releaseHost = quayMirrors[0].mirrors[0].split('/')[0] if quayMirrors | length > 0 else 'quay.io' -%}
apiVersion: hive.openshift.io/v1
kind: ClusterImageSet
metadata:
  name: img{{ cluster.version }}-{{ arch }}-appsub
  labels:
    visible: "true"
    channel: stable
    vendor: OpenShift
    version: "{{ cluster.version }}"
    arch: {{ imageArch }}
spec:
  releaseImage: {{ releaseHost }}/openshift-release-dev/ocp-release:{{ cluster.version }}-{{ imageArch }}
