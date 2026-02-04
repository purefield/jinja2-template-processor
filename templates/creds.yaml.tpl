{# Unified credentials template for OpenShift IPI platforms #}
{# Generates CCO (Cloud Credential Operator) secrets for manual mode #}
{# Supports: aws, azure, gcp, vsphere, openstack, ibmcloud, nutanix #}
{%- set platform = cluster.platform | default('baremetal', true) -%}
{%- set platformPlugin = plugins[platform] | default({}) if plugins is defined else {} -%}
{%- if platformPlugin.credentials is defined or platform in ['vsphere', 'nutanix', 'openstack'] -%}
{% include 'includes/platforms/' ~ platform ~ '/creds.yaml.tpl' %}
{%- endif -%}
