{#- @meta
name: pre-check-dns.sh
description: DNS forward and reverse lookup verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{% include 'includes/pre-check/common.sh.tpl' %}
{%- set has_vips = network.primary is defined and network.primary.vips is defined %}
{%- set has_hosts = hosts is defined and hosts | length > 0 %}
{%- set has_nameservers = network.nameservers is defined and network.nameservers | length > 0 %}

{%- if has_vips or has_hosts %}

section "DNS Forward"
{%- if has_vips %}
for h in api.{{ cluster.name }}.{{ network.domain }} api-int.{{ cluster.name }}.{{ network.domain }}; do
    result=$(dig +short "$h" 2>/dev/null | tail -1)
    [ -n "$result" ] && pass "$h → $result" || warn "$h not found"
done
{%- if network.primary.vips.apps is defined %}
result=$(dig +short test.apps.{{ cluster.name }}.{{ network.domain }} 2>/dev/null | tail -1)
[ -n "$result" ] && pass "*.apps.{{ cluster.name }}.{{ network.domain }} → wildcard OK" || warn "*.apps wildcard not configured"
{%- endif %}
{%- endif %}
{%- if has_hosts %}
{%- for name, host in hosts.items() %}
result=$(dig +short "{{ name }}" 2>/dev/null | tail -1)
[ -n "$result" ] && pass "{{ name }} → $result" || warn "{{ name }} not found"
{%- endfor %}
{%- endif %}
{%- endif %}
{%- if has_vips and network.primary.vips.api is defined %}

section "DNS Reverse"
{%- for vip in network.primary.vips.api %}
result=$(dig +short -x "{{ vip }}" 2>/dev/null | head -1)
[ -n "$result" ] && pass "{{ vip }} → $result" || warn "{{ vip }} no PTR"
{%- endfor %}
{%- if hosts is defined %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
result=$(dig +short -x "{{ host.network.primary.address }}" 2>/dev/null | head -1)
[ -n "$result" ] && pass "{{ host.network.primary.address }} → $result" || warn "{{ host.network.primary.address }} no PTR"
{%- endif %}
{%- endfor %}
{%- endif %}
{%- endif %}
{%- if has_nameservers %}

section "DNS Resolvers"
{%- for ns in network.nameservers %}
dig @"{{ ns }}" +short +time=2 google.com &>/dev/null && pass "{{ ns }} responding" || warn "{{ ns }} not responding"
{%- endfor %}
{%- endif %}

summary
