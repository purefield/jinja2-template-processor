{# AWS CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_aws/installing-aws-customizations.html#manually-create-iam_installing-aws-customizations #}
{# Expects aws.credentials to point to a file with INI format: #}
{# [default] #}
{# aws_access_key_id = AKIA... #}
{# aws_secret_access_key = ... #}
{% set aws = plugins.aws %}
apiVersion: v1
kind: Secret
metadata:
  name: aws-creds
  namespace: kube-system
type: Opaque
stringData:
  credentials: |
{{ load_file(aws.credentials) | indent(4, true) }}
