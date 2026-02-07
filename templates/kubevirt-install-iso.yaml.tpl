{#- @meta
name: kubevirt-install-iso.yaml
description: DataVolume to download a discovery ISO for KubeVirt VM boot
type: clusterfile
category: installation
platforms:
  - kubevirt
requires:
  - cluster.name
  - imageUrl (pass via -p imageUrl=<url>)
relatedTemplates:
  - kubevirt-cluster.yaml.tpl
  - acm-ztp.yaml.tpl
docs: https://docs.openshift.com/container-platform/4.20/virt/about_virt/about-virt.html
-#}
{%- set namespace = cluster.name + "-cluster" -%}
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: {{ cluster.name }}-install-iso
  namespace: {{ namespace }}
spec:
  source:
    http:
      url: "{{ imageUrl }}"
  storage:
    resources:
      requests:
        storage: 5Gi
