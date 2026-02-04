{# GCP CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_gcp/installing-gcp-customizations.html#manually-create-iam_installing-gcp-customizations #}
{% set gcp = plugins.gcp %}
apiVersion: v1
kind: Secret
metadata:
  name: gcp-credentials
  namespace: kube-system
type: Opaque
stringData:
  service_account.json: |
{{ load_file(gcp.credentials) | indent(4, true) }}
