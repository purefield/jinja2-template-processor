apiVersion: v1 {%- set sources %}{% include "includes/imageContentSource.yaml.tpl" %}{% endset %}
kind: List
metadata:
  resourceVersion: ""
items:
- kind: ImageDigestMirrorSet
  apiVersion: config.openshift.io/v1
  metadata:
    name: mirror-registries
  spec:
    imageDigestMirrors:
{{ sources | indent(8, true)}}
- kind: ImageTagMirrorSet
  apiVersion: config.openshift.io/v1
  metadata:
    name: mirror-registries
  spec:
    imageTagMirrors:
{{ sources | indent(8, true)}}
