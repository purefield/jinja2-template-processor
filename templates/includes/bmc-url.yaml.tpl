{% if    host.bmc.vendor == 'dell'             %}{{ 'redfish' if host.bmc.version | default(9) >= 9 else 'idrac' }}-virtualmedia://{{ host.bmc.address }}{% include "bmc-redfish-path.tpl" %}
{%- elif host.bmc.vendor in ('hp', 'hpe')      %}redfish-virtualmedia://{{ host.bmc.address }}{% include "bmc-redfish-path.tpl" %}
{%- elif host.bmc.vendor == 'kubevirt-redfish' %}redfish-virtualmedia+https://{{ host.bmc.address }}{% include "bmc-redfish-path.tpl" %}
{%- elif host.bmc.address is defined           %}{{ host.bmc.address }}{% endif %}