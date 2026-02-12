{#- @meta
name: poc-banner.yaml
description: ConsoleNotification banner marking the cluster as a Proof of Concept
type: clusterfile
category: configuration
platforms:
  - baremetal
  - kubevirt
  - aws
  - azure
  - gcp
  - vsphere
  - openstack
  - ibmcloud
  - nutanix
  - none
requires:
  - cluster.name
relatedTemplates:
  - install-config.yaml.tpl
  - agent-config.yaml.tpl
  - acm-ztp.yaml.tpl
  - acm-capi-m3.yaml.tpl
docs: https://docs.openshift.com/container-platform/4.21/web_console/customizing-the-web-console.html
-#}
apiVersion: console.openshift.io/v1
kind: ConsoleNotification
metadata:
  name: poc-banner
spec:
  text: "This is a Proof of Concept and not for production use"
  location: BannerTop
  color: "#fff"
  backgroundColor: "#e00"
