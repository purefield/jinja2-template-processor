apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:{%- set enabledFalse='{"enabled":false}' %}{% for network in network.secondary %}{%- set interface=network.ports[0] %}{%- set interfaceName=interface %}
- kind: NodeNetworkConfigurationPolicy
  apiVersion: nmstate.io/v1
  spec:
    desiredState:
      interfaces:{% if network.bond %}{% set interface=network.name ~ '-bond' %}
        - type: bond
          name: {{ interface }}
          state: {{ network.state|default('up')}}{% if network.mtu %}
          mtu: {{ network.mtu }}{% endif %}
          ipv4: {{ enabledFalse }}
          ipv6: {{ enabledFalse }}
          link-aggregation:
            mode: {{ network.bond|default('active-backup') }}
            options:
              miimon: "100"
              primary: {{ network.ports[0] }}
            port: {{ network.ports }}{% endif %}{% if network.vlan %}
        - type: vlan
          state: {{ network.state|default('up')}}{% if network.mtu %}
          mtu: {{ network.mtu }}{% endif %}
          vlan:
            base-iface: {{ interface }}{% set interface=interface ~ "." ~ network.vlan %}
            id: {{ network.vlan }}
          name: {{ interface }}
          ipv4: { enabled: false }
          ipv6: { enabled: false }{% endif %}{% if network.type == 'bridge' %}{% set interfaceName='br-' ~ interface | replace('.', '-v')%}
        - name: {{ interfaceName }}
          type: linux-bridge
          state: {{ network.state|default('up')}}
          bridge:
            options: { stp: { enabled: false }}
            port:
              - name: {{ interface }}
                vlan: {}
          ipv4: {{ enabledFalse }}
          ipv6: {{ enabledFalse }}{% endif %}
  metadata:
    name: {{ network.name }}
    annotations:{% set description %}{{ network.name }} network on {{ interface }}{% endset %}
      description: {{ description }}
- kind: NetworkAttachmentDefinition
  apiVersion: k8s.cni.cncf.io/v1
  metadata:
    name: {{ interfaceName }}-network
    annotations:
      description: {{ description }}
  spec:
    config: |-
      {
        "name": "{{ interfaceName }}-network",

        {%- if network.type == 'bridge' %}
        "bridge": "{{ interfaceName }}",
        "type": "cnv-bridge",
        "macspoofchk": true,

        {%- elif network.type == 'macvlan' %}
        "type": "macvlan",
        "master": "{{ interface }}",
        "linkInContainer": false,
        "mode": "bridge",

        {%- endif %}
        "cniVersion": "0.3.1"
        "ipam": {

        {%- if network.subnet == 'dhcp' %}
           "type": "dhcp"

        {%- else %}
           "type": "whereabouts",
           "range": {{ network.subnet }}

        {%- endif%}
        }
      }{% endfor %}
