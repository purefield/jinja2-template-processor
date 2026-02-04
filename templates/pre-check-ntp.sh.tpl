{#- @meta
name: pre-check-ntp.sh
description: NTP server connectivity verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{% include 'includes/pre-check/common.sh.tpl' %}
{%- if network.ntpservers is defined and network.ntpservers | length > 0 %}

section "NTP"
{%- for ntp in network.ntpservers %}
if timeout 2 bash -c "echo > /dev/udp/{{ ntp }}/123" 2>/dev/null; then
    pass "{{ ntp }}:123 reachable"
else
    warn "{{ ntp }}:123 not reachable"
fi
{%- endfor %}
{%- endif %}

summary
