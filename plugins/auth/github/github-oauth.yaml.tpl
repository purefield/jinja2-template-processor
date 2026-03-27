apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:{% for provider in auth.github.providers | default([]) %}
    - name: {{ provider.name }}
      mappingMethod: {{ auth.github.mappingMethod | default("claim") }}
      type: GitHub
      github:
        clientID: {{ provider.clientId | tojson }}
        clientSecret:
          name: {{ provider.secretName }}
        hostname: {{ auth.github.hostname | default("") | tojson }}
        organizations: {{ provider.organizations | default([]) | tojson }}
        teams: {{ provider.teams | default([]) | tojson }}{% endfor %}
