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
section "DNS Forward"
{%- if network.primary is defined and network.primary.vips is defined %}
for h in api.{{ cluster.name }}.{{ network.domain }} api-int.{{ cluster.name }}.{{ network.domain }}; do
    result=$(dig +short "$h" 2>/dev/null | tail -1)
    [ -n "$result" ] && pass "$h → $result" || warn "$h not found"
done
{%- if network.primary.vips.apps is defined %}
result=$(dig +short test.apps.{{ cluster.name }}.{{ network.domain }} 2>/dev/null | tail -1)
[ -n "$result" ] && pass "*.apps.{{ cluster.name }}.{{ network.domain }} → wildcard OK" || warn "*.apps wildcard not configured"
{%- endif %}
{%- endif %}
{%- for name, host in (hosts | default({})).items() %}
result=$(dig +short "{{ name }}" 2>/dev/null | tail -1)
[ -n "$result" ] && pass "{{ name }} → $result" || warn "{{ name }} not found"
{%- endfor %}
{%- if network.primary is defined and network.primary.vips is defined and network.primary.vips.api is defined %}

section "DNS Reverse"
{%- for vip in network.primary.vips.api %}
result=$(dig +short -x "{{ vip }}" 2>/dev/null | head -1)
[ -n "$result" ] && pass "{{ vip }} → $result" || warn "{{ vip }} no PTR"
{%- endfor %}
{%- for name, host in (hosts | default({})).items()
    if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
result=$(dig +short -x "{{ host.network.primary.address }}" 2>/dev/null | head -1)
[ -n "$result" ] && pass "{{ host.network.primary.address }} → $result" || warn "{{ host.network.primary.address }} no PTR"
{%- endfor %}
{%- endif %}
{%- for ns in network.nameservers | default([]) %}
{%- if loop.first %}

section "DNS Resolvers"
{%- endif %}
dig @"{{ ns }}" +short +time=2 google.com &>/dev/null && pass "{{ ns }} responding" || warn "{{ ns }} not responding"
{%- endfor %}

summary
