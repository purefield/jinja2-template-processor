GitHub OAuth app settings for {{ cluster.name }}
===============================================
{% for provider in plugins.auth.github.providers | default([]) %}
Provider: {{ provider.name }}
Client ID file: {{ provider.clientIdFile }}
Client secret file: {{ provider.clientSecretFile }}
Homepage URL: https://oauth-openshift.apps.{{ cluster.name }}.{{ network.domain }}/
Authorization callback URL: https://oauth-openshift.apps.{{ cluster.name }}.{{ network.domain }}/oauth2callback/{{ provider.name }}{% if not loop.last %}

{% endif %}{% endfor %}
