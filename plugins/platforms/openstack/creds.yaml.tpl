{# OpenStack CCO credentials for manual mode #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_openstack/installing-openstack-installer-custom.html #}
{% set osp = plugins.openstack %}
apiVersion: v1
kind: Secret
metadata:
  name: openstack-credentials
  namespace: kube-system
type: Opaque
stringData:{% if osp.cloudsYaml is defined %}
  clouds.yaml: |
{{ load_file(osp.cloudsYaml) | indent(4, true) }}{% else %}
  clouds.yaml: |
    clouds:
      {{ osp.cloud }}:
        auth:
          auth_url: {{ osp.authURL }}
          project_name: {{ osp.projectName }}
          username: {{ osp.username }}
          password: {{ load_file(osp.password) | trim }}
          user_domain_name: {{ osp.userDomainName | default('Default', true) }}
          project_domain_name: {{ osp.projectDomainName | default('Default', true) }}
        region_name: {{ osp.region | default('regionOne', true) }}{% endif %}
