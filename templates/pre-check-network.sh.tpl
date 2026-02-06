{#- @meta
name: pre-check-network.sh
description: Network connectivity checks (hosts, gateway, VIPs, proxy)
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{% include 'includes/pre-check/common.sh.tpl' %}
section "Network"
{%- for name, host in (hosts | default({})).items()
    if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
ping -c 1 -W 2 "{{ host.network.primary.address }}" &>/dev/null && pass "{{ name }} ({{ host.network.primary.address }}) pingable" || warn "{{ name }} ({{ host.network.primary.address }}) not pingable"
{%- endfor %}
{%- if network.primary is defined and network.primary.gateway is defined %}
ping -c 1 -W 2 "{{ network.primary.gateway }}" &>/dev/null && pass "gateway {{ network.primary.gateway }} reachable" || warn "gateway {{ network.primary.gateway }} not reachable"
{%- endif %}
{%- if network.primary is defined and network.primary.vips is defined and network.primary.vips.api is defined %}

section "VIP Availability"
{%- for vip in network.primary.vips.api %}
! ping -c 1 -W 1 "{{ vip }}" &>/dev/null && pass "API VIP {{ vip }} not in use" || warn "API VIP {{ vip }} already in use"
{%- endfor %}
{%- for vip in network.primary.vips.apps | default([]) %}
! ping -c 1 -W 1 "{{ vip }}" &>/dev/null && pass "Apps VIP {{ vip }} not in use" || warn "Apps VIP {{ vip }} already in use"
{%- endfor %}
{%- endif %}
{%- if network.proxy is defined and network.proxy.httpProxy is defined %}

section "Proxy"
curl -s --proxy "{{ network.proxy.httpProxy }}" --connect-timeout 5 -o /dev/null https://quay.io && pass "proxy {{ network.proxy.httpProxy }} reachable" || warn "proxy {{ network.proxy.httpProxy }} not reachable"
{%- endif %}

summary
