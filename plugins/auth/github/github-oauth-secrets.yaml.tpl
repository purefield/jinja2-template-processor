apiVersion: v1
kind: List
items:{% for provider in auth.github.providers | default([]) %}
  - apiVersion: v1
    kind: Secret
    metadata:
      name: {{ provider.secretName }}
      namespace: {{ auth.github.secretNamespace | default("openshift-config") }}
    stringData:
      clientSecret: {{ provider.clientSecret | tojson }}{% endfor %}
