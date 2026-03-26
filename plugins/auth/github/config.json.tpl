{%- set github = (plugins.auth | default({})).github | default({}) -%}
{
  "rolebindingName": {{ ("rlinks" if cluster.name == "rlinks" else "purefield") | tojson }},
  "auth": {
    "github": {
      "hostname": {{ (github.hostname | default("")) | tojson }},
      "mappingMethod": {{ (github.mappingMethod | default("claim")) | tojson }},
      "secretNamespace": {{ (github.secretNamespace | default("openshift-config")) | tojson }},
      "providers": {{ (github.providers | default([])) | tojson }}
    }
  }
}
