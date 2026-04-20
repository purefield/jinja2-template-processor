{%- set _github = (auth | default({})).get('github', {}) -%}
{%- set providers = _github.get('providers', []) -%}
{%- if providers -%}
{%- set githubProviderNames = providers | map(attribute='name') | list -%}
{%- set ns = namespace(identityProviders=[]) -%}
{%- for provider in _github.get('existingIdentityProviders', []) -%}
  {%- if provider.name not in githubProviderNames -%}
    {%- set ns.identityProviders = ns.identityProviders + [provider] -%}
  {%- endif -%}
{%- endfor -%}
{%- for provider in providers -%}
  {%- set ns.identityProviders = ns.identityProviders + [{
    "github": {
      "clientID": provider.clientId,
      "clientSecret": {"name": provider.secretName},
      "hostname": _github.get('hostname', ''),
      "organizations": provider.organizations | default([]),
      "teams": provider.teams | default([])
    },
    "mappingMethod": _github.get('mappingMethod', 'claim'),
    "name": provider.name,
    "type": "GitHub"
  }] -%}
{%- endfor -%}
{{ {"spec": {"identityProviders": ns.identityProviders}} | tojson }}
{%- endif -%}
