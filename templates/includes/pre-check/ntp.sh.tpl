{#- Pre-check body: NTP connectivity -#}
{%- for ntp in network.ntpservers | default([]) %}
{%- if loop.first %}
section "NTP"
{%- endif %}
if timeout 2 bash -c "echo > /dev/udp/{{ ntp }}/123" 2>/dev/null; then
    pass "{{ ntp }}:123 reachable"
else
    warn "{{ ntp }}:123 not reachable"
fi
{%- endfor %}
