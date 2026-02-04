{#- @meta
name: pre-check.sh
description: Pre-installation verification script for DNS, NTP, registry access, and network connectivity
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
  - network.primary.vips
  - network.ntpservers
  - network.nameservers
  - account.pullSecret
  - hosts
relatedTemplates:
  - install-config.yaml.tpl
  - agent-config.yaml.tpl
docs: https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html#installation-infrastructure-user-infra_installing-bare-metal
-#}
#!/bin/bash
# OpenShift Pre-Installation Verification Script
# Generated from clusterfile: {{ cluster.name }}.{{ network.domain }}
# Run this script to verify infrastructure prerequisites before installation

set -e
PASS=0
FAIL=0
WARN=0

pass() { echo -e "  \033[32m✓\033[0m $1"; ((PASS++)); }
fail() { echo -e "  \033[31m✗\033[0m $1"; ((FAIL++)); }
warn() { echo -e "  \033[33m!\033[0m $1"; ((WARN++)); }
info() { echo -e "  \033[34m→\033[0m $1"; }

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  OpenShift Pre-Installation Check - {{ cluster.name }}  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# DNS Verification
# ============================================================================
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ DNS Forward Lookups                                           │"
echo "└────────────────────────────────────────────────────────────────┘"

check_dns_forward() {
    local host=$1
    local result=$(dig +short "$host" 2>/dev/null | head -1)
    if [ -n "$result" ]; then
        pass "$host → $result"
        return 0
    else
        fail "$host → NOT FOUND"
        return 1
    fi
}

# API and Ingress VIPs
check_dns_forward "api.{{ cluster.name }}.{{ network.domain }}"
check_dns_forward "api-int.{{ cluster.name }}.{{ network.domain }}"
check_dns_forward "*.apps.{{ cluster.name }}.{{ network.domain }}" || \
    check_dns_forward "test.apps.{{ cluster.name }}.{{ network.domain }}" || \
    warn "Wildcard DNS for *.apps may not be configured (checked test.apps)"

# Host DNS
{% for name, host in hosts.items() %}
check_dns_forward "{{ name }}"
{% endfor %}

echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ DNS Reverse Lookups (PTR records)                             │"
echo "└────────────────────────────────────────────────────────────────┘"

check_dns_reverse() {
    local ip=$1
    local result=$(dig +short -x "$ip" 2>/dev/null | head -1)
    if [ -n "$result" ]; then
        pass "$ip → $result"
        return 0
    else
        warn "$ip → NO PTR (optional but recommended)"
        return 1
    fi
}

{% if network.primary.vips is defined %}
{% if network.primary.vips.api is defined %}
{% for vip in network.primary.vips.api if network.primary.vips.api is iterable and network.primary.vips.api is not string %}
check_dns_reverse "{{ vip }}"
{% else %}
check_dns_reverse "{{ network.primary.vips.api }}"
{% endfor %}
{% endif %}
{% if network.primary.vips.apps is defined %}
{% for vip in network.primary.vips.apps if network.primary.vips.apps is iterable and network.primary.vips.apps is not string %}
check_dns_reverse "{{ vip }}"
{% else %}
check_dns_reverse "{{ network.primary.vips.apps }}"
{% endfor %}
{% endif %}
{% endif %}

{% for name, host in hosts.items() %}
{% if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
check_dns_reverse "{{ host.network.primary.address }}"
{% endif %}
{% endfor %}

# ============================================================================
# NTP Verification
# ============================================================================
echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ NTP Server Connectivity                                       │"
echo "└────────────────────────────────────────────────────────────────┘"

check_ntp() {
    local server=$1
    # Try ntpdate query first, fall back to nc check on port 123
    if command -v ntpdate &>/dev/null; then
        if ntpdate -q "$server" &>/dev/null; then
            pass "NTP $server → reachable (ntpdate)"
            return 0
        fi
    fi
    # Try chronyd/chronyc if available
    if command -v chronyc &>/dev/null; then
        if chronyc -h "$server" tracking &>/dev/null; then
            pass "NTP $server → reachable (chronyc)"
            return 0
        fi
    fi
    # Fall back to UDP port check
    if timeout 3 bash -c "echo > /dev/udp/$server/123" 2>/dev/null; then
        pass "NTP $server → port 123/udp open"
        return 0
    elif nc -zu -w3 "$server" 123 &>/dev/null; then
        pass "NTP $server → port 123/udp open (nc)"
        return 0
    else
        fail "NTP $server → NOT reachable"
        return 1
    fi
}

{% if network.ntpservers is defined %}
{% for ntp in network.ntpservers %}
check_ntp "{{ ntp }}"
{% endfor %}
{% else %}
warn "No NTP servers configured in clusterfile"
{% endif %}

# ============================================================================
# DNS Resolver Verification
# ============================================================================
echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ DNS Resolver Connectivity                                     │"
echo "└────────────────────────────────────────────────────────────────┘"

check_dns_server() {
    local server=$1
    if dig @"$server" +short +time=3 google.com &>/dev/null || \
       dig @"$server" +short +time=3 "api.{{ cluster.name }}.{{ network.domain }}" &>/dev/null; then
        pass "DNS $server → responding"
        return 0
    else
        fail "DNS $server → NOT responding"
        return 1
    fi
}

{% if network.nameservers is defined %}
{% for ns in network.nameservers %}
check_dns_server "{{ ns }}"
{% endfor %}
{% else %}
warn "No nameservers configured in clusterfile"
{% endif %}

# ============================================================================
# Container Registry Access
# ============================================================================
echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ Container Registry Connectivity                               │"
echo "└────────────────────────────────────────────────────────────────┘"

{% if account.pullSecret is defined %}
# Pull secret path: {{ account.pullSecret }}
PULL_SECRET="{{ account.pullSecret }}"

check_registry() {
    local registry=$1
    local auth=""

    # Extract auth from pull secret if available
    if [ -f "$PULL_SECRET" ]; then
        auth=$(jq -r ".auths.\"$registry\".auth // empty" "$PULL_SECRET" 2>/dev/null)
    fi

    # Test HTTPS connectivity
    local http_code
    if [ -n "$auth" ]; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Basic $auth" \
            --connect-timeout 10 "https://$registry/v2/" 2>/dev/null)
    else
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout 10 "https://$registry/v2/" 2>/dev/null)
    fi

    case $http_code in
        200|401|403)
            pass "Registry $registry → reachable (HTTP $http_code)"
            return 0
            ;;
        000)
            fail "Registry $registry → connection failed"
            return 1
            ;;
        *)
            warn "Registry $registry → HTTP $http_code"
            return 1
            ;;
    esac
}

# Standard Red Hat registries
check_registry "quay.io"
check_registry "registry.redhat.io"
check_registry "registry.access.redhat.com"

{% if cluster.mirrors is defined %}
# Mirror registries from clusterfile
{% for mirror in cluster.mirrors %}
{% for m in mirror.mirrors %}
check_registry "{{ m.split('/')[0] }}"
{% endfor %}
{% endfor %}
{% endif %}

{% else %}
warn "No pull secret configured - cannot verify registry authentication"
{% endif %}

# ============================================================================
# Network Connectivity Tests
# ============================================================================
echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ Network Connectivity                                          │"
echo "└────────────────────────────────────────────────────────────────┘"

check_host_ping() {
    local host=$1
    local ip=$2
    if ping -c 1 -W 3 "$ip" &>/dev/null; then
        pass "Host $host ($ip) → pingable"
        return 0
    else
        warn "Host $host ($ip) → not pingable (may be blocked)"
        return 1
    fi
}

{% for name, host in hosts.items() %}
{% if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
check_host_ping "{{ name }}" "{{ host.network.primary.address }}"
{% endif %}
{% endfor %}

# Check gateway
{% if network.primary.gateway is defined %}
if ping -c 1 -W 3 "{{ network.primary.gateway }}" &>/dev/null; then
    pass "Gateway {{ network.primary.gateway }} → reachable"
else
    fail "Gateway {{ network.primary.gateway }} → NOT reachable"
fi
{% endif %}

{% if network.proxy is defined %}
# ============================================================================
# Proxy Connectivity
# ============================================================================
echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ Proxy Connectivity                                            │"
echo "└────────────────────────────────────────────────────────────────┘"

check_proxy() {
    local proxy_url=$1
    local proxy_host=$(echo "$proxy_url" | sed -e 's|https\?://||' -e 's|:.*||')
    local proxy_port=$(echo "$proxy_url" | sed -e 's|.*:||' -e 's|/.*||')

    if nc -z -w5 "$proxy_host" "$proxy_port" &>/dev/null; then
        pass "Proxy $proxy_url → reachable"
        return 0
    else
        fail "Proxy $proxy_url → NOT reachable"
        return 1
    fi
}

{% if network.proxy.httpProxy is defined %}
check_proxy "{{ network.proxy.httpProxy }}"
{% endif %}
{% if network.proxy.httpsProxy is defined %}
check_proxy "{{ network.proxy.httpsProxy }}"
{% endif %}
{% endif %}

{% if hosts.values() | selectattr('bmc', 'defined') | list | length > 0 %}
# ============================================================================
# BMC Connectivity (for baremetal)
# ============================================================================
echo ""
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│ BMC/IPMI Connectivity                                         │"
echo "└────────────────────────────────────────────────────────────────┘"

check_bmc() {
    local host=$1
    local bmc_addr=$2

    if ping -c 1 -W 3 "$bmc_addr" &>/dev/null; then
        pass "BMC $host ($bmc_addr) → pingable"
        # Check HTTPS (Redfish)
        if curl -s -k -o /dev/null -w "%{http_code}" --connect-timeout 5 \
            "https://$bmc_addr/redfish/v1/" 2>/dev/null | grep -qE "^(200|401|403)"; then
            pass "BMC $host → Redfish API available"
        fi
        return 0
    else
        fail "BMC $host ($bmc_addr) → NOT reachable"
        return 1
    fi
}

{% for name, host in hosts.items() %}
{% if host.bmc is defined and host.bmc.address is defined %}
check_bmc "{{ name }}" "{{ host.bmc.address }}"
{% endif %}
{% endfor %}
{% endif %}

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        SUMMARY                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "  \033[32mPassed:\033[0m  $PASS"
echo -e "  \033[31mFailed:\033[0m  $FAIL"
echo -e "  \033[33mWarnings:\033[0m $WARN"
echo ""

if [ $FAIL -gt 0 ]; then
    echo -e "\033[31m⚠ There are $FAIL failed checks. Please resolve before installation.\033[0m"
    exit 1
elif [ $WARN -gt 0 ]; then
    echo -e "\033[33m⚠ There are $WARN warnings. Review before proceeding.\033[0m"
    exit 0
else
    echo -e "\033[32m✓ All checks passed. Ready for installation.\033[0m"
    exit 0
fi
