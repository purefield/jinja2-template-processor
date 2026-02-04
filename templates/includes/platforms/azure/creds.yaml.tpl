{# Azure CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_azure/installing-azure-customizations.html#manually-create-iam_installing-azure-customizations #}
{# Expects azure.credentials to point to a JSON file with Azure SP credentials #}
{% set azure = plugins.azure %}
apiVersion: v1
kind: Secret
metadata:
  name: azure-credentials
  namespace: kube-system
type: Opaque
stringData:
  azure_resource_prefix: {{ cluster.name }}
  azure_resourcegroup: {{ cluster.name }}-rg
  azure_region: {{ azure.region }}
  osServicePrincipal.json: |
{{ load_file(azure.credentials) | indent(4, true) }}
