{%- set _github = (auth | default({})).get('github', {}) -%}
{%- set providers = _github.get('providers', []) -%}
{%- if providers %}
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:{% for provider in providers %}
    - name: {{ provider.name }}
      mappingMethod: {{ _github.get('mappingMethod', 'claim') }}
      type: GitHub
      github:
        clientID: {{ provider.clientId | tojson }}
        clientSecret:
          name: {{ provider.secretName }}
        hostname: {{ _github.get('hostname', '') | tojson }}
        organizations: {{ provider.organizations | default([]) | tojson }}
        teams: {{ provider.teams | default([]) | tojson }}{% endfor %}
{%- endif -%}
