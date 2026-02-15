{% set azure = plugins.azure %}
  azure:
    baseDomainResourceGroupName: {{ azure.baseDomainResourceGroupName }}
    region: {{ azure.region }}{% if azure.cloudName is defined and azure.cloudName != "AzurePublicCloud" %}
    cloudName: {{ azure.cloudName }}{%- endif %}{% if azure.networkResourceGroupName is defined %}
    networkResourceGroupName: {{ azure.networkResourceGroupName }}{%- endif %}{% if azure.virtualNetwork is defined %}
    virtualNetwork: {{ azure.virtualNetwork }}{%- endif %}{% if azure.controlPlaneSubnet is defined %}
    controlPlaneSubnet: {{ azure.controlPlaneSubnet }}{%- endif %}{% if azure.computeSubnet is defined %}
    computeSubnet: {{ azure.computeSubnet }}{%- endif %}{% if azure.outboundType is defined and azure.outboundType != "Loadbalancer" %}
    outboundType: {{ azure.outboundType }}{%- endif -%}
