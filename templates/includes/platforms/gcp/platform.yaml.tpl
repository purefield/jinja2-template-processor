{% set gcp = plugins.gcp %}
  gcp:
    projectID: {{ gcp.projectID }}
    region: {{ gcp.region }}
{%- if gcp.network is defined %}
    network: {{ gcp.network }}
{%- endif %}
{%- if gcp.controlPlaneSubnet is defined %}
    controlPlaneSubnet: {{ gcp.controlPlaneSubnet }}
{%- endif %}
{%- if gcp.computeSubnet is defined %}
    computeSubnet: {{ gcp.computeSubnet }}
{%- endif -%}
