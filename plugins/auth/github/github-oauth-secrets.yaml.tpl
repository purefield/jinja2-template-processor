{%- set _github = (auth | default({})).get('github', {}) -%}
{%- set providers = _github.get('providers', []) -%}
{%- if providers %}
apiVersion: v1
kind: List
items:{% for provider in providers %}
  - apiVersion: v1
    kind: Secret
    metadata:
      name: {{ provider.secretName }}
      namespace: {{ _github.get('secretNamespace', 'openshift-config') }}
    stringData:
      clientSecret: {{ provider.clientSecret | tojson }}{% endfor %}
{%- endif -%}
