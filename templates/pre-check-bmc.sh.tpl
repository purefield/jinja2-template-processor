{#- @meta
name: pre-check-bmc.sh
description: BMC/Redfish connectivity verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{% include 'includes/pre-check/common.sh.tpl' %}
{%- set hosts_with_bmc = [] %}
{%- if hosts is defined %}
{%- for name, host in hosts.items() %}
{%- if host.bmc is defined and host.bmc.address is defined %}
{%- set _ = hosts_with_bmc.append({'name': name, 'addr': host.bmc.address}) %}
{%- endif %}
{%- endfor %}
{%- endif %}

{%- if hosts_with_bmc | length > 0 %}

section "BMC"
{%- for h in hosts_with_bmc %}
ping -c 1 -W 2 "{{ h.addr }}" &>/dev/null && pass "{{ h.name }} BMC ({{ h.addr }}) pingable" || warn "{{ h.name }} BMC ({{ h.addr }}) not pingable"
{%- endfor %}

section "Redfish"
{%- for h in hosts_with_bmc %}
code=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://{{ h.addr }}/redfish/v1/" 2>/dev/null)
[[ "$code" =~ ^(200|401|403)$ ]] && pass "{{ h.name }} Redfish API responds" || warn "{{ h.name }} Redfish HTTP $code"
{%- endfor %}
{%- endif %}

summary
