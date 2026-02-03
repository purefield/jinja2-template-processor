{# AWS IPI install-config.yaml template #}
{# https://docs.openshift.com/container-platform/latest/installing/installing_aws/ipi/installing-aws-customizations.html #}
{%- set controlCount = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list | length -%}
{%- set workerCount  = hosts.values() | selectattr('role', 'equalto', 'worker') | list | length -%}
{%- set aws = plugins.aws -%}
---
apiVersion: v1
metadata:
  name: {{ cluster.name }}

baseDomain: {{ network.domain }}

controlPlane:
  name: master
  replicas: {{ controlCount }}
  platform:
    aws:
      type: {{ aws.controlPlane.type | default("m6i.xlarge", true) }}
{%- if aws.controlPlane.zones is defined %}
      zones:
{%- for zone in aws.controlPlane.zones %}
        - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if aws.controlPlane.rootVolume is defined %}
      rootVolume:
        size: {{ aws.controlPlane.rootVolume.size | default(120, true) }}
        type: {{ aws.controlPlane.rootVolume.type | default("gp3", true) }}
{%- if aws.controlPlane.rootVolume.iops is defined %}
        iops: {{ aws.controlPlane.rootVolume.iops }}
{%- endif %}
{%- endif %}

compute:
  - name: worker
    replicas: {{ workerCount }}
    platform:
      aws:
        type: {{ aws.compute.type | default("m6i.xlarge", true) }}
{%- if aws.compute.zones is defined %}
        zones:
{%- for zone in aws.compute.zones %}
          - {{ zone }}
{%- endfor %}
{%- endif %}
{%- if aws.compute.rootVolume is defined %}
        rootVolume:
          size: {{ aws.compute.rootVolume.size | default(120, true) }}
          type: {{ aws.compute.rootVolume.type | default("gp3", true) }}
{%- endif %}

{%- if network.proxy is defined %}

proxy:
  httpProxy: {{ network.proxy.httpProxy }}
  httpsProxy: {{ network.proxy.httpsProxy }}
  noProxy: {{ network.proxy.noProxy }}
{%- endif %}

networking:
  networkType: {{ network.primary.type | default("OVNKubernetes", true) }}
  clusterNetwork:
    - cidr: {{ network.cluster.subnet }}
      hostPrefix: {{ network.cluster.hostPrefix | default(23, true) }}
  machineNetwork:
    - cidr: {{ network.primary.subnet }}
  serviceNetwork:
    - {{ network.service.subnet }}

platform:
  aws:
    region: {{ aws.region }}
{%- if aws.subnets is defined and aws.subnets | length > 0 %}
    subnets:
{%- for subnet in aws.subnets %}
      - {{ subnet }}
{%- endfor %}
{%- endif %}
{%- if aws.hostedZone is defined %}
    hostedZone: {{ aws.hostedZone }}
{%- endif %}
{%- if aws.serviceEndpoints is defined and aws.serviceEndpoints | length > 0 %}
    serviceEndpoints:
{%- for ep in aws.serviceEndpoints %}
      - name: {{ ep.name }}
        url: {{ ep.url }}
{%- endfor %}
{%- endif %}

publish: External
pullSecret: '{{ load_file(account.pullSecret) | trim }}'
sshKey: |
{%- for pubKey in cluster.sshKeys %}
  {{ load_file(pubKey) | trim }}
{%- endfor %}
{%- if network.trustBundle is defined %}

additionalTrustBundle: |
{{ load_file(network.trustBundle) | indent(2, true) }}
{%- endif %}
{%- if cluster.mirrors is defined and cluster.mirrors | length > 0 %}

imageContentSources:
{%- for mirror in cluster.mirrors %}
  - source: {{ mirror.source }}
    mirrors:
{%- for m in mirror.mirrors %}
      - {{ m }}
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- if aws.credentials is defined %}

credentialsMode: Manual
{%- endif %}
