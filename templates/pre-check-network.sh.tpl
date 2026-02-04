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
{%- set hosts_with_ip = [] %}
{%- if hosts is defined %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
{%- set _ = hosts_with_ip.append({'name': name, 'ip': host.network.primary.address}) %}
{%- endif %}
{%- endfor %}
{%- endif %}
{%- set has_gateway = network.primary is defined and network.primary.gateway is defined %}
{%- set has_vips = network.primary is defined and network.primary.vips is defined %}
{%- set has_proxy = network.proxy is defined and network.proxy.httpProxy is defined %}

{%- if hosts_with_ip | length > 0 or has_gateway %}

section "Network"
{%- for h in hosts_with_ip %}
ping -c 1 -W 2 "{{ h.ip }}" &>/dev/null && pass "{{ h.name }} ({{ h.ip }}) pingable" || warn "{{ h.name }} ({{ h.ip }}) not pingable"
{%- endfor %}
{%- if has_gateway %}
ping -c 1 -W 2 "{{ network.primary.gateway }}" &>/dev/null && pass "gateway {{ network.primary.gateway }} reachable" || warn "gateway {{ network.primary.gateway }} not reachable"
{%- endif %}
{%- endif %}
{%- if has_vips %}
{%- if network.primary.vips.api is defined %}

section "VIP Availability"
{%- for vip in network.primary.vips.api %}
! ping -c 1 -W 1 "{{ vip }}" &>/dev/null && pass "API VIP {{ vip }} not in use" || warn "API VIP {{ vip }} already in use"
{%- endfor %}
{%- endif %}
{%- if network.primary.vips.apps is defined %}
{%- for vip in network.primary.vips.apps %}
! ping -c 1 -W 1 "{{ vip }}" &>/dev/null && pass "Apps VIP {{ vip }} not in use" || warn "Apps VIP {{ vip }} already in use"
{%- endfor %}
{%- endif %}
{%- endif %}
{%- if has_proxy %}

section "Proxy"
{%- set proxy_url = network.proxy.httpProxy %}
curl -s --proxy "{{ proxy_url }}" --connect-timeout 5 -o /dev/null https://quay.io && pass "proxy {{ proxy_url }} reachable" || warn "proxy {{ proxy_url }} not reachable"
{%- endif %}

summary
