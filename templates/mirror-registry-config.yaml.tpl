apiVersion: v1 {%- set sources %}{% include "includes/imageContentSource.yaml.tpl" %}{% endset %}
kind: List
metadata:
  resourceVersion: ""
items:
- kind: ImageContentSourcePolicy
  apiVersion: operator.openshift.io/v1alpha1
  metadata:
    name: mirror-registries
  spec:
    repositoryDigestMirrors:
{{ sources | indent(8, true)}}
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
    name: global
  spec:
    imageTagMirrors:
{{ sources | indent(8, true)}}
