{# Nutanix CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_nutanix/installing-nutanix-installer-provisioned.html #}
{% set nutanix = plugins.nutanix %}
apiVersion: v1
kind: Secret
metadata:
  name: nutanix-credentials
  namespace: openshift-machine-api
type: Opaque
stringData:
  credentials: |
    [{"type":"basic_auth","data":{"prismCentral":{"username":"{{ nutanix.prismCentral.username }}","password":"{{ load_file(nutanix.prismCentral.password) | trim }}"}}}]
