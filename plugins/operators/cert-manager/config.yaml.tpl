{%- set cm = plugins.operators['cert-manager'] -%}
{%- if cm.letsencrypt is defined -%}
{%- set le = cm.letsencrypt -%}
{%- set r53 = le.route53 -%}
{%- set selfCheck = cm.selfCheck | default({}) -%}
{%- set nameservers = selfCheck.nameservers | default(["8.8.8.8:53", "1.1.1.1:53"]) -%}
{%- set clusterDomain = cluster.name ~ '.' ~ network.domain %}
---
apiVersion: operator.openshift.io/v1alpha1
kind: CertManager
metadata:
  name: cluster
spec:
  controllerConfig:
    overrideArgs:
      - --dns01-recursive-nameservers-only
      - --dns01-recursive-nameservers={{ nameservers | join(',') }}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: route53-credentials
  namespace: cert-manager
spec:
  secretStoreRef:
    name: {{ r53.secretStore | default("vault") }}
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
      - dns01:{% if le.cnameStrategy is defined %}
          cnameStrategy: {{ le.cnameStrategy }}{% endif %}
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
{%- endif -%}
