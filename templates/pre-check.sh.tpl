{#- @meta
name: pre-check.sh
description: Comprehensive pre-installation verification (composes all modules)
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
relatedTemplates:
  - install-config.yaml.tpl
  - agent-config.yaml.tpl
  - pre-check-files.sh.tpl
  - pre-check-dns.sh.tpl
  - pre-check-network.sh.tpl
  - pre-check-ntp.sh.tpl
  - pre-check-registry.sh.tpl
  - pre-check-bmc.sh.tpl
docs: https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html#installation-infrastructure-user-infra_installing-bare-metal
-#}
#!/bin/bash
# OpenShift Pre-Check Script
# Generated for: {{ cluster.name }}.{{ network.domain }}

PASS=0; WARN=0; SECTION=""
pass() { echo -e "  \033[32m✓\033[0m $1"; ((PASS++)); }
warn() { echo -e "  \033[33m!\033[0m $1"; ((WARN++)); }
section() { [ -n "$SECTION" ] && echo ""; SECTION="$1"; echo "$1:"; }

echo "═══════════════════════════════════════"
echo "  Pre-Check: {{ cluster.name }}.{{ network.domain }}"
echo "═══════════════════════════════════════"

#
# FILES
#
{%- set has_files = (account is defined and account.pullSecret is defined) or (cluster.sshKeys is defined) or (network.trustBundle is defined) or (cluster.manifests is defined and cluster.manifests | length > 0) %}
{%- set has_bmc_passwords = false %}
{%- if hosts is defined %}
{%- for name, host in hosts.items() %}
{%- if host.bmc is defined and host.bmc.password is defined %}
{%- set has_bmc_passwords = true %}
{%- endif %}
{%- endfor %}
{%- endif %}
{%- if has_files or has_bmc_passwords %}

section "Files"
{%- if account is defined and account.pullSecret is defined %}
if [ -f "{{ account.pullSecret }}" ]; then
    jq . "{{ account.pullSecret }}" &>/dev/null && pass "{{ account.pullSecret }} valid JSON" || warn "{{ account.pullSecret }} invalid JSON"
else
    warn "{{ account.pullSecret }} not found"
fi
{%- endif %}
{%- if cluster.sshKeys is defined %}
{%- for key in cluster.sshKeys | unique %}
if [ -f "{{ key }}" ]; then
    ssh-keygen -l -f "{{ key }}" &>/dev/null && pass "{{ key }} valid SSH key" || warn "{{ key }} invalid format"
else
    warn "{{ key }} not found"
fi
{%- endfor %}
{%- endif %}
{%- if network.trustBundle is defined %}
if [ -f "{{ network.trustBundle }}" ]; then
    openssl x509 -in "{{ network.trustBundle }}" -noout &>/dev/null && pass "{{ network.trustBundle }} valid PEM" || warn "{{ network.trustBundle }} invalid PEM"
else
    warn "{{ network.trustBundle }} not found"
fi
{%- endif %}
{%- if cluster.manifests is defined %}
{%- for manifest in cluster.manifests %}
[ -f "{{ manifest.file }}" ] && pass "{{ manifest.file }} exists" || warn "{{ manifest.file }} not found"
{%- endfor %}
{%- endif %}
{%- if hosts is defined %}
{%- for name, host in hosts.items() %}
{%- if host.bmc is defined and host.bmc.password is defined %}
[ -f "{{ host.bmc.password }}" ] && pass "{{ host.bmc.password }} exists" || warn "{{ host.bmc.password }} not found ({{ name }})"
{%- endif %}
{%- endfor %}
{%- endif %}
{%- endif %}

#
# DNS
#
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

#
# NETWORK
#
{%- set hosts_with_ip = [] %}
{%- if hosts is defined %}
{%- for name, host in hosts.items() %}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
{%- set _ = hosts_with_ip.append({'name': name, 'ip': host.network.primary.address}) %}
{%- endif %}
{%- endfor %}
{%- endif %}
{%- set has_gateway = network.primary is defined and network.primary.gateway is defined %}
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

#
# NTP
#
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

#
# REGISTRY
#
{%- set has_pull_secret = account is defined and account.pullSecret is defined %}
{%- set has_mirrors = cluster.mirrors is defined and cluster.mirrors | length > 0 %}
{%- if has_pull_secret or has_mirrors %}

section "Registry"
{%- if has_pull_secret %}
PULL_SECRET="{{ account.pullSecret }}"
check_registry() {
    local registry=$1 auth="" code
    [ -f "$PULL_SECRET" ] && auth=$(jq -r ".auths.\"$registry\".auth // empty" "$PULL_SECRET" 2>/dev/null)
    if [ -n "$auth" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Basic $auth" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    fi
    [[ "$code" =~ ^(200|401|403)$ ]] && pass "$registry reachable" || warn "$registry HTTP $code"
}
check_registry "quay.io"
check_registry "registry.redhat.io"
{%- if has_mirrors %}
{%- set checked_registries = [] %}
{%- for mirror in cluster.mirrors %}
{%- for m in mirror.mirrors %}
{%- set registry_host = m.split('/')[0] %}
{%- if registry_host not in checked_registries %}
{%- set _ = checked_registries.append(registry_host) %}
check_registry "{{ registry_host }}"
{%- endif %}
{%- endfor %}
{%- endfor %}
{%- endif %}
{%- else %}
for registry in quay.io registry.redhat.io; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    [[ "$code" =~ ^(200|401|403)$ ]] && pass "$registry reachable" || warn "$registry HTTP $code"
done
{%- endif %}
{%- endif %}

#
# BMC
#
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

echo ""
echo "═══════════════════════════════════════"
echo -e "  \033[32m✓\033[0m $PASS passed   \033[33m!\033[0m $WARN warnings"
echo "═══════════════════════════════════════"
