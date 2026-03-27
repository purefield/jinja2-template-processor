{%- set github = (plugins.auth | default({})).github | default({}) -%}
{%- set providers = namespace(items=[]) -%}
{%- for provider in github.providers | default([]) -%}
  {%- set providers.items = providers.items + [{
    'name': provider.name,
    'secretName': provider.secretName,
    'externalSecretName': provider.externalSecretName,
    'organizations': provider.organizations | default([]),
    'teams': provider.teams | default([])
  }] -%}
{%- endfor -%}
{
  "rolebindingName": {{ ("rlinks" if cluster.name == "rlinks" else "purefield") | tojson }},
  "auth": {
    "github": {
      "hostname": {{ (github.hostname | default("")) | tojson }},
      "mappingMethod": {{ (github.mappingMethod | default("claim")) | tojson }},
      "secretNamespace": {{ (github.secretNamespace | default("openshift-config")) | tojson }},
      "providers": {{ providers.items | tojson }}
    }
  }
}
