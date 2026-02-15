{%- set cm = plugins.operators['cert-manager'] -%}
{%- set le = cm.letsencrypt -%}
{%- set r53 = le.route53 -%}
{%- set clusterDomain = cluster.name ~ '.' ~ network.domain %}
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: route53-credentials
  namespace: cert-manager
spec:
  secretStoreRef:
    name: {{ r53.secretStore | default("aws-secretsmanager") }}
    kind: ClusterSecretStore
  target:
    name: route53-credentials
  data:
    - secretKey: aws-access-key-id
      remoteRef:
        key: {{ r53.remoteRef }}
        property: aws-access-key-id
    - secretKey: aws-secret-access-key
      remoteRef:
        key: {{ r53.remoteRef }}
        property: aws-secret-access-key
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: {{ le.email }}
    privateKeySecretRef:
      name: letsencrypt-acme-account-key
    solvers:
      - dns01:
          route53:
            region: {{ r53.region | default("us-east-1") }}
            hostedZoneID: {{ r53.hostedZoneID }}
            role: {{ r53.role }}
            accessKeyIDSecretRef:
              name: route53-credentials
              key: aws-access-key-id
            secretAccessKeySecretRef:
              name: route53-credentials
              key: aws-secret-access-key
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ cluster.name }}-ingress-cert
  namespace: openshift-ingress
spec:
  secretName: letsencrypt-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - api.{{ clusterDomain }}
    - "*.apps.{{ clusterDomain }}"
