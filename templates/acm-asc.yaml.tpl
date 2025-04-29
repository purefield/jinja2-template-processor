apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:
- kind: ConfigMap
  apiVersion: v1
  metadata:
    name: assisted-service-config
    namespace: multicluster-engine
    labels:
      app: assisted-service
  data:
    LOG_LEVEL: "info"
    AUTH_TYPE: "none"
    SKIP_CERT_VERIFICATION: "True"
    ISO_IMAGE_TYPE: "full-iso"{% if network.proxy %}
    HTTP_PROXY: {{ network.proxy.httpProxy }}
    HTTPS_PROXY: {{ network.proxy.httpsProxy }}
    NO_PROXY: {{ network.proxy.noProxy }}{% endif %}
- kind: Provisioning
  apiVersion: metal3.io/v1alpha1
  metadata:
    name: provisioning-configuration
  spec:
    provisioningNetwork: "Disabled"
    watchAllNamespaces: true
    # https://docs.openshift.com/container-platform/4.16/edge_computing/ztp-deploying-far-edge-sites.html#ztp-troubleshooting-ztp-gitops-supermicro-tls_ztp-deploying-far-edge-sites
    disableVirtualMediaTLS: true
