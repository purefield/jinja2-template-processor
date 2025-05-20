{%- set bootNic = host.network.interfaces | selectattr('name', 'equalto', host.network.primary.ports[0]) | first -%}
{%- set nextHopInterface=host.network.primary.ports[0] %}
{%- set ipv4={"enabled":true,"address":[{"ip":host.network.primary.address,"prefix-length":network.primary.subnet.split('/')[1]|int}],"dhcp":false} %}
  interfaces:{% for interface in host.network.interfaces %}
    - type: ethernet
      name: {{ interface.name }}{% if network.primary.mtu %}
      mtu: {{ network.primary.mtu }}{% endif %}
      state: up
      ipv4: {{ enabledFalse if interface.name != nextHopInterface or network.primary.vlan or network.primary.bond else ipv4 }}
      ipv6: {{ enabledFalse }}{% endfor %}{%- if network.primary.bond %}{% set nextHopInterface="bond0" %}
    - type: bond
      name: bond0{% if network.primary.mtu %}
      mtu: {{ network.primary.mtu }}{% endif %}
      state: up
      ipv4: {{ enabledFalse if network.primary.vlan else ipv4 }}
      ipv6: {{ enabledFalse }}
      link-aggregation:
        mode: {{ network.primary.bond }}
        options:
          miimon: "150"
          primary: {{ host.network.primary.ports[0] }}
        port: {{ host.network.primary.ports }}{% endif %}{% if network.primary.vlan %}
    - type: vlan
      vlan:
        base-iface: {{ nextHopInterface }}{% set nextHopInterface=nextHopInterface ~ "." ~ network.primary.vlan %}
        id: {{ network.primary.vlan }}{% endif %}
      name: {{ nextHopInterface }}
      ipv4: {{ ipv4 }}
      ipv6: {{ enabledFalse }}{% if network.primary.mtu %}
      mtu: {{ network.primary.mtu }}{% endif %}
      state: up
  dns-resolver:
    config:
      server: {{ network.nameservers }}{% if network.dnsResolver and network.dnsResolver.search %}
      search: {{ network.dnsResolver.search }}{% endif %}
  routes:
    config:
      - destination: 0.0.0.0/0
        next-hop-address: {{ network.primary.gateway }}
        next-hop-interface: {{ nextHopInterface }}
        table-id: 254
interfaces:{% for interface in host.network.interfaces %}
  - name: {{ interface.name }}
    macAddress: {{ interface.macAddress }}{% endfor %}

