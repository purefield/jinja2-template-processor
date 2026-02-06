{% set ibm = plugins.ibmcloud %}
  ibmcloud:
    region: {{ ibm.region }}
    resourceGroupName: {{ ibm.resourceGroupName }}{% if ibm.vpcName is defined %}
    vpcName: {{ ibm.vpcName }}{%- endif %}{% if ibm.controlPlaneSubnets is defined and ibm.controlPlaneSubnets | length > 0 %}
    controlPlaneSubnets:{% for subnet in ibm.controlPlaneSubnets %}
      - {{ subnet }}{%- endfor %}{% endif %}{% if ibm.computeSubnets is defined and ibm.computeSubnets | length > 0 %}
    computeSubnets:{% for subnet in ibm.computeSubnets %}
      - {{ subnet }}{%- endfor %}{%- endif %}
