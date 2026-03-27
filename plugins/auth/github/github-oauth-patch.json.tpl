{%- set githubProviderNames = auth.github.providers | default([]) | map(attribute='name') | list -%}
{%- set ns = namespace(identityProviders=[]) -%}
{%- for provider in auth.github.existingIdentityProviders | default([]) -%}
  {%- if provider.name not in githubProviderNames -%}
    {%- set ns.identityProviders = ns.identityProviders + [provider] -%}
  {%- endif -%}
{%- endfor -%}
{%- for provider in auth.github.providers | default([]) -%}
  {%- set ns.identityProviders = ns.identityProviders + [{
    "github": {
      "clientID": provider.clientId,
      "clientSecret": {"name": provider.secretName},
      "hostname": auth.github.hostname | default(""),
      "organizations": provider.organizations | default([]),
      "teams": provider.teams | default([])
    },
    "mappingMethod": auth.github.mappingMethod | default("claim"),
    "name": provider.name,
    "type": "GitHub"
  }] -%}
{%- endfor -%}
{{ {"spec": {"identityProviders": ns.identityProviders}} | tojson }}
