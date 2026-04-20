{%- set providers = ((plugins | default({})).get('auth', {}) or {}).get('github', {}).get('providers', []) -%}
{%- if providers %}
GitHub OAuth app settings for {{ cluster.name }}
===============================================
{% for provider in providers %}
Provider: {{ provider.name }}
Vault secret name: {{ provider.externalSecretName }}
Homepage URL: https://oauth-openshift.apps.{{ cluster.name }}.{{ network.domain }}/
Authorization callback URL: https://oauth-openshift.apps.{{ cluster.name }}.{{ network.domain }}/oauth2callback/{{ provider.name }}{% if not loop.last %}

{% endif %}{% endfor %}
{%- endif -%}
