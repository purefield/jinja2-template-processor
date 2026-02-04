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

set -e
PASS=0; FAIL=0; WARN=0
pass() { echo -e "  \033[32m✓\033[0m $1"; ((PASS++)); }
fail() { echo -e "  \033[31m✗\033[0m $1"; ((FAIL++)); }
warn() { echo -e "  \033[33m!\033[0m $1"; ((WARN++)); }

echo "═══════════════════════════════════════════════════════"
echo "  Pre-Installation Check: {{ cluster.name }}.{{ network.domain }}"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- DNS Forward Lookups ---
echo "DNS Forward Lookups:"
check_dns() {
    local host=$1
    local result=$(dig +short "$host" 2>/dev/null | head -1)
    [ -n "$result" ] && pass "$host → $result" || fail "$host → NOT FOUND"
}
{%- if network.primary is defined and network.primary.vips is defined %}
check_dns "api.{{ cluster.name }}.{{ network.domain }}"
check_dns "api-int.{{ cluster.name }}.{{ network.domain }}"
{%- endif %}
{%- for name, host in hosts.items() %}
check_dns "{{ name }}"
{%- endfor %}
echo ""
{%- if network.primary is defined and network.primary.vips is defined %}

# --- DNS Reverse Lookups ---
echo "DNS Reverse Lookups:"
check_ptr() {
    local ip=$1
    local result=$(dig +short -x "$ip" 2>/dev/null | head -1)
    [ -n "$result" ] && pass "$ip → $result" || warn "$ip → no PTR"
}
{%- if network.primary.vips.api is defined %}
check_ptr "{{ network.primary.vips.api }}"
{%- endif %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
check_ptr "{{ host.network.primary.address }}"
{%- endif %}
{%- endfor %}
echo ""
{%- endif %}
{%- if network.ntpservers is defined and network.ntpservers | length > 0 %}

# --- NTP Servers ---
echo "NTP Server Connectivity:"
check_ntp() {
    local server=$1
    if command -v ntpdate &>/dev/null && ntpdate -q "$server" &>/dev/null; then
        pass "NTP $server → reachable"
    elif timeout 2 bash -c "echo > /dev/udp/$server/123" 2>/dev/null; then
        pass "NTP $server → port open"
    else
        fail "NTP $server → NOT reachable"
    fi
}
{%- for ntp in network.ntpservers %}
check_ntp "{{ ntp }}"
{%- endfor %}
echo ""
{%- endif %}
{%- if network.nameservers is defined and network.nameservers | length > 0 %}

# --- DNS Resolvers ---
echo "DNS Resolver Connectivity:"
check_resolver() {
    local server=$1
    dig @"$server" +short +time=2 google.com &>/dev/null && pass "DNS $server → responding" || fail "DNS $server → NOT responding"
}
{%- for ns in network.nameservers %}
check_resolver "{{ ns }}"
{%- endfor %}
echo ""
{%- endif %}
{%- if account is defined and account.pullSecret is defined %}

# --- Container Registries ---
echo "Container Registry Connectivity:"
PULL_SECRET="{{ account.pullSecret }}"
check_registry() {
    local registry=$1
    local auth=""
    [ -f "$PULL_SECRET" ] && auth=$(jq -r ".auths.\"$registry\".auth // empty" "$PULL_SECRET" 2>/dev/null)
    local code
    if [ -n "$auth" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Basic $auth" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    fi
    [[ "$code" =~ ^(200|401|403)$ ]] && pass "Registry $registry → reachable" || fail "Registry $registry → HTTP $code"
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
echo ""
{%- endif %}
{%- set hosts_with_ip = [] %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
{%- set _ = hosts_with_ip.append({'name': name, 'ip': host.network.primary.address}) %}
{%- endif %}
{%- endfor %}
{%- if hosts_with_ip | length > 0 %}

# --- Host Network Connectivity ---
echo "Host Network Connectivity:"
{%- for h in hosts_with_ip %}
ping -c 1 -W 2 "{{ h.ip }}" &>/dev/null && pass "{{ h.name }} ({{ h.ip }}) → pingable" || warn "{{ h.name }} ({{ h.ip }}) → not pingable"
{%- endfor %}
{%- if network.primary is defined and network.primary.gateway is defined %}
ping -c 1 -W 2 "{{ network.primary.gateway }}" &>/dev/null && pass "Gateway {{ network.primary.gateway }} → reachable" || fail "Gateway → NOT reachable"
{%- endif %}
echo ""
{%- endif %}
{%- set hosts_with_bmc = [] %}
{%- for name, host in hosts.items() %}
{%- if host.bmc is defined and host.bmc.address is defined %}
{%- set _ = hosts_with_bmc.append({'name': name, 'addr': host.bmc.address}) %}
{%- endif %}
{%- endfor %}
{%- if hosts_with_bmc | length > 0 %}

# --- BMC Connectivity ---
echo "BMC Connectivity:"
{%- for h in hosts_with_bmc %}
ping -c 1 -W 2 "{{ h.addr }}" &>/dev/null && pass "BMC {{ h.name }} ({{ h.addr }}) → reachable" || fail "BMC {{ h.name }} → NOT reachable"
{%- endfor %}
echo ""
{%- endif %}

# --- Summary ---
echo "═══════════════════════════════════════════════════════"
echo -e "  Passed: \033[32m$PASS\033[0m  Failed: \033[31m$FAIL\033[0m  Warnings: \033[33m$WARN\033[0m"
echo "═══════════════════════════════════════════════════════"
[ $FAIL -gt 0 ] && exit 1 || exit 0
