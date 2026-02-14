{% if    host.bmc.vendor == 'dell'             %}{{ 'redfish' if host.bmc.version | default(9) >= 9 else 'idrac' }}-virtualmedia://{{ host.bmc.address }}/redfish/v1/Systems/System.Embedded.1
{%- elif host.bmc.vendor == 'hp'               %}redfish-virtualmedia+https://{{ host.bmc.address }}/redfish/v1/Systems/1
{%- elif host.bmc.vendor == 'ksushy'           %}redfish-virtualmedia://{{ host.bmc.address }}/redfish/v1/Systems/{{ cluster.name }}-cluster/{{ name | replace(".", "-") }}
{%- elif host.bmc.vendor == 'kubevirt-redfish' %}redfish-virtualmedia+https://{{ host.bmc.address }}/redfish/v1/Systems/{{ name | replace('.', '-') }}
{%- elif host.bmc.address is defined           %}{{ host.bmc.address }}{% endif %}