{%- set imageArch = cluster.arch | default("x86_64", true) | replace("-", "_") -%}
{%- set arch = imageArch | replace("_", "-") -%}
{%- set quayMirrors = (cluster.mirrors | default([])) | selectattr('source', 'equalto', 'quay.io') | list -%}
{%- set releaseHost = quayMirrors[0].mirrors[0].split('/')[0] if quayMirrors | length > 0 else 'quay.io' -%}
- apiVersion: hive.openshift.io/v1
  kind: ClusterImageSet
  metadata:
    labels:
      channel: fast
      visible: "true"
    name: img{{ cluster.version }}-{{ arch }}-appsub
  spec:
    releaseImage: {{ releaseHost }}/openshift-release-dev/ocp-release{% if cluster.releaseDigest is defined %}@{{ cluster.releaseDigest }}{% else %}:{{ cluster.version }}-{{ imageArch }}{% endif %}
