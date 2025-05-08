apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: mirror-registries
spec:
  repositoryDigestMirrors: {%- set sources %}{% include "includes/imageContentSource.yaml.tpl" %}{% endset %}
{{ sources | indent(6, true)}}
