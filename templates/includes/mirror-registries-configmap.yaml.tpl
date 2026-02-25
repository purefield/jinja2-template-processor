{% if cluster.mirrors %}
- kind: ConfigMap
  apiVersion: v1
  metadata:
    name: mirror-registries-{{ cluster.name }}
    namespace: multicluster-engine
    labels:
      app: assisted-service
  data:{% if network.trustBundle %}
    ca-bundle.crt: |
{{ load_file(network.trustBundle)|safe|indent(6,true) }}{% endif %}
    registries.conf: |{%- set registries %}{% include "includes/registries.conf.tpl" %}{% endset %}
{{ registries | indent(6,true) }}{% endif %}