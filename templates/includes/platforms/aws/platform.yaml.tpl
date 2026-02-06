{% set aws = plugins.aws %}
  aws:
    region: {{ aws.region }}{% if aws.subnets is defined and aws.subnets | length > 0 %}
    subnets:{% for subnet in aws.subnets %}
      - {{ subnet }}{%- endfor %}{% endif %}{% if aws.hostedZone is defined %}
    hostedZone: {{ aws.hostedZone }}{%- endif %}{% if aws.serviceEndpoints is defined and aws.serviceEndpoints | length > 0 %}
    serviceEndpoints:{% for ep in aws.serviceEndpoints %}
      - name: {{ ep.name }}
        url: {{ ep.url }}{%- endfor %}{%- endif -%}
