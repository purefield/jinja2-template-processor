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
      interfaces:{%- if network.primary.bond %}{% set ifName="bond0" %}
        - type: bond
          name: {{ ifName }}{% if network.primary.mtu %}
          mtu: {{ network.primary.mtu }}{% endif %}
          state: up
          ipv4: {{ enabledFalse if network.primary.vlan else ipv4 }}
          ipv6: {{ enabledFalse }}
          link-aggregation:
            mode: {{ network.primary.bond }}
            options:
              miimon: "150"
            port: {{ host.network.primary.ports }}{% else %}
        - type: ethernet
          name: {{ ifName }}{% if network.primary.mtu %}
          mtu: {{ network.primary.mtu }}{% endif %}
          state: up
          ipv4: {{ enabledFalse if network.primary.vlan else ipv4 }}
          ipv6: {{ enabledFalse }}{% endif %}{%- if network.primary.vlan %}
        - type: vlan
          name: {{ ifName ~ "." ~ network.primary.vlan }}
          ipv4: {{ ipv4 }}
          ipv6: {{ enabledFalse }}{% if network.primary.mtu %}
          mtu: {{ network.primary.mtu }}{% endif %}
          state: up
          vlan:
            base-iface: {{ ifName }}
            id: {{ network.primary.vlan }}{% set ifName=ifName ~ "." ~ network.primary.vlan %}{% endif %}
      dns-resolver:
        config:
          server: {{ network.nameservers }}{% if network.dnsResolver and network.dnsResolver.search %}
          search: {{ network.dnsResolver.search }}{% endif %}
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: {{ network.primary.gateway }}
            next-hop-interface: {{ ifName }}
            table-id: 254{%- endfor -%}
