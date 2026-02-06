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
section "BMC"
{%- for name, host in (hosts | default({})).items() if host.bmc is defined and host.bmc.address is defined %}
ping -c 1 -W 2 "{{ host.bmc.address }}" &>/dev/null && pass "{{ name }} BMC ({{ host.bmc.address }}) pingable" || warn "{{ name }} BMC ({{ host.bmc.address }}) not pingable"
{%- endfor %}

section "Redfish"
{%- for name, host in (hosts | default({})).items() if host.bmc is defined and host.bmc.address is defined %}
code=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://{{ host.bmc.address }}/redfish/v1/" 2>/dev/null)
[[ "$code" =~ ^(200|401|403)$ ]] && pass "{{ name }} Redfish API responds" || warn "{{ name }} Redfish HTTP $code"
{%- endfor %}

summary
