{# IBM Cloud CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_ibm_cloud_public/installing-ibm-cloud-customizations.html #}
{% set ibm = plugins.ibmcloud %}
apiVersion: v1
kind: Secret
metadata:
  name: ibmcloud-credentials
  namespace: kube-system
type: Opaque
stringData:
  ibmcloud_api_key: {{ load_file(ibm.credentials) | trim }}
