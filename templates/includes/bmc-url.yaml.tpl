{% if    host.bmc.vendor == 'dell'             %}{{ 'redfish' if host.bmc.version | default(9) >= 9 else 'idrac' }}-virtualmedia://{{ host.bmc.address }}/redfish/v1/Systems/System.Embedded.1
{%- elif host.bmc.vendor in ('hp', 'hpe')      %}redfish-virtualmedia://{{ host.bmc.address }}/redfish/v1/Systems/1
{%- elif host.bmc.vendor == 'kubevirt-redfish' %}redfish-virtualmedia+https://{{ host.bmc.address }}/redfish/v1/Systems/{{ name | replace('.', '-') }}
{%- elif host.bmc.address is defined           %}{{ host.bmc.address }}{% endif %}