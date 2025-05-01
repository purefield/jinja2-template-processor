# bond the primary interface and use a VLAN interface for br-ex
# after install, provision br-vmdata directly on bond0
{% set firstHostName,firstHost = hosts.items() | first %}
{% set enabledFalse='{"enabled":false}' %}
---
apiVersion: v1alpha1
kind: AgentConfig
metadata:
  name: {{ cluster.name }}
rendezvousIP: {{ firstHost.network.primary.address }}
additionalNTPSources: {{ network.ntpservers }}
hosts:{% for name,host in hosts.items() %}
  - hostname: {{ name }}{% if host.storage.os %}
    rootDeviceHints: {{ host.storage.os }}{% endif %}
    interfaces: {{ host.network.interfaces }}{% set ifName = host.network.primary.ports | first %}
    networkConfig:{% set ipv4={"enabled":true,"address":[{"ip":host.network.primary.address,"prefix-length":network.primary.subnet.split('/')[1]|int}],"dhcp":false} %}
      interfaces:{% set nextHopInterface=host.network.primary.ports[0] %}{% for interface in host.network.interfaces %}
        - type: ethernet
          name: {{ interface.name }}
          mac-address: {{ interface.macAddress }}{% if network.primary.lldp %}
          lldp: {enabled: true}{% endif %}{% if network.primary.mtu %}
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
            table-id: 254{%- endfor -%}
