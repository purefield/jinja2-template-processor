{#- @meta
name: pre-check.sh
description: Pre-installation verification script for DNS, NTP, registry, and network
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
relatedTemplates:
  - install-config.yaml.tpl
  - agent-config.yaml.tpl
docs: https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html#installation-infrastructure-user-infra_installing-bare-metal
-#}
#!/bin/bash
# OpenShift Pre-Installation Verification Script
# Generated for: {{ cluster.name }}.{{ network.domain }}

PASS=0; WARN=0
pass() { echo -e "  \033[32m✓\033[0m $1"; ((PASS++)); }
warn() { echo -e "  \033[33m!\033[0m $1"; ((WARN++)); }

echo "═══════════════════════════════════════════════════════"
echo "  Pre-Installation Check: {{ cluster.name }}.{{ network.domain }}"
echo "═══════════════════════════════════════════════════════"
{%- if network.primary is defined and network.primary.vips is defined %}

echo ""
echo "DNS Forward Lookups:"
for h in api.{{ cluster.name }}.{{ network.domain }} api-int.{{ cluster.name }}.{{ network.domain }}{% for name, host in hosts.items() %} {{ name }}{% endfor %}; do
    result=$(dig +short "$h" 2>/dev/null | tail -1)
    [ -n "$result" ] && pass "$h → $result" || warn "$h → not found"
done
{%- endif %}
{%- if network.primary is defined and network.primary.vips is defined and network.primary.vips.api is defined %}

echo ""
echo "DNS Reverse Lookups:"
{%- if network.primary.vips.api is defined %}
result=$(dig +short -x "{{ network.primary.vips.api }}" 2>/dev/null | head -1)
[ -n "$result" ] && pass "{{ network.primary.vips.api }} → $result" || warn "{{ network.primary.vips.api }} → no PTR"
{%- endif %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
result=$(dig +short -x "{{ host.network.primary.address }}" 2>/dev/null | head -1)
[ -n "$result" ] && pass "{{ host.network.primary.address }} → $result" || warn "{{ host.network.primary.address }} → no PTR"
{%- endif %}
{%- endfor %}
{%- endif %}
{%- if network.ntpservers is defined and network.ntpservers | length > 0 %}

echo ""
echo "NTP Server Connectivity:"
{%- for ntp in network.ntpservers %}
if timeout 2 bash -c "echo > /dev/udp/{{ ntp }}/123" 2>/dev/null; then
    pass "NTP {{ ntp }} → reachable"
else
    warn "NTP {{ ntp }} → not reachable"
fi
{%- endfor %}
{%- endif %}
{%- if network.nameservers is defined and network.nameservers | length > 0 %}

echo ""
echo "DNS Resolver Connectivity:"
{%- for ns in network.nameservers %}
dig @"{{ ns }}" +short +time=2 google.com &>/dev/null && pass "DNS {{ ns }} → responding" || warn "DNS {{ ns }} → not responding"
{%- endfor %}
{%- endif %}
{%- if account is defined and account.pullSecret is defined %}

echo ""
echo "Container Registry Connectivity:"
PULL_SECRET="{{ account.pullSecret }}"
check_registry() {
    local registry=$1 auth="" code
    [ -f "$PULL_SECRET" ] && auth=$(jq -r ".auths.\"$registry\".auth // empty" "$PULL_SECRET" 2>/dev/null)
    if [ -n "$auth" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Basic $auth" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    fi
    [[ "$code" =~ ^(200|401|403)$ ]] && pass "Registry $registry → reachable" || warn "Registry $registry → HTTP $code"
}
check_registry "quay.io"
check_registry "registry.redhat.io"
{%- if cluster.mirrors is defined %}
{%- for mirror in cluster.mirrors %}
{%- for m in mirror.mirrors %}
check_registry "{{ m.split('/')[0] }}"
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- endif %}
{%- set hosts_with_ip = [] %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
{%- set _ = hosts_with_ip.append({'name': name, 'ip': host.network.primary.address}) %}
{%- endif %}
{%- endfor %}
{%- if hosts_with_ip | length > 0 %}

echo ""
echo "Host Network Connectivity:"
{%- for h in hosts_with_ip %}
ping -c 1 -W 2 "{{ h.ip }}" &>/dev/null && pass "{{ h.name }} ({{ h.ip }}) → pingable" || warn "{{ h.name }} ({{ h.ip }}) → not pingable"
{%- endfor %}
{%- if network.primary is defined and network.primary.gateway is defined %}
ping -c 1 -W 2 "{{ network.primary.gateway }}" &>/dev/null && pass "Gateway {{ network.primary.gateway }} → reachable" || warn "Gateway → not reachable"
{%- endif %}
{%- endif %}
{%- set hosts_with_bmc = [] %}
{%- for name, host in hosts.items() %}
{%- if host.bmc is defined and host.bmc.address is defined %}
{%- set _ = hosts_with_bmc.append({'name': name, 'addr': host.bmc.address}) %}
{%- endif %}
{%- endfor %}
{%- if hosts_with_bmc | length > 0 %}

echo ""
echo "BMC Connectivity:"
{%- for h in hosts_with_bmc %}
ping -c 1 -W 2 "{{ h.addr }}" &>/dev/null && pass "BMC {{ h.name }} ({{ h.addr }}) → reachable" || warn "BMC {{ h.name }} → not reachable"
{%- endfor %}
{%- endif %}

echo ""
echo "═══════════════════════════════════════════════════════"
echo -e "  Passed: \033[32m$PASS\033[0m  Warnings: \033[33m$WARN\033[0m"
echo "═══════════════════════════════════════════════════════"
