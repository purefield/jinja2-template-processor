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

# ── FILES ─────────────────────────────────

section "Files"
{%- if account is defined and account.pullSecret is defined %}
if [ -f "{{ account.pullSecret }}" ]; then
    if jq -e '.auths' "{{ account.pullSecret }}" &>/dev/null; then
        pass "{{ account.pullSecret }} valid pull secret"
    else
        warn "{{ account.pullSecret }} invalid (missing auths)"
    fi
else
    warn "{{ account.pullSecret }} not found"
fi
{%- endif %}
{%- for key in cluster.sshKeys | default([]) | unique %}
if [ -f "{{ key }}" ]; then
    ssh-keygen -l -f "{{ key }}" &>/dev/null && pass "{{ key }} valid SSH key" || warn "{{ key }} invalid format"
else
    warn "{{ key }} not found"
fi
{%- endfor %}
{%- if network.trustBundle is defined %}
if [ -f "{{ network.trustBundle }}" ]; then
    openssl x509 -in "{{ network.trustBundle }}" -noout &>/dev/null && pass "{{ network.trustBundle }} valid PEM" || warn "{{ network.trustBundle }} invalid PEM"
else
    warn "{{ network.trustBundle }} not found"
fi
{%- endif %}
{%- for manifest in cluster.manifests | default([]) %}
[ -f "{{ manifest.file }}" ] && pass "{{ manifest.file }} exists" || warn "{{ manifest.file }} not found"
{%- endfor %}
{%- for name, host in (hosts | default({})).items() if host.bmc is defined and host.bmc.password is defined %}
[ -f "{{ host.bmc.password }}" ] && pass "{{ host.bmc.password }} exists" || warn "{{ host.bmc.password }} not found ({{ name }})"
{%- endfor %}

# ── DNS ───────────────────────────────────

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

# ── NETWORK ───────────────────────────────

section "Network"
{%- for name, host in (hosts | default({})).items()
    if host.network is defined and host.network.primary is defined and host.network.primary.address is defined %}
ping -c 1 -W 2 "{{ host.network.primary.address }}" &>/dev/null && pass "{{ name }} ({{ host.network.primary.address }}) pingable" || warn "{{ name }} ({{ host.network.primary.address }}) not pingable"
{%- endfor %}
{%- if network.primary is defined and network.primary.gateway is defined %}
ping -c 1 -W 2 "{{ network.primary.gateway }}" &>/dev/null && pass "gateway {{ network.primary.gateway }} reachable" || warn "gateway {{ network.primary.gateway }} not reachable"
{%- endif %}
{%- if network.primary is defined and network.primary.vips is defined and network.primary.vips.api is defined %}

section "VIP Availability"
{%- for vip in network.primary.vips.api %}
! ping -c 1 -W 1 "{{ vip }}" &>/dev/null && pass "API VIP {{ vip }} not in use" || warn "API VIP {{ vip }} already in use"
{%- endfor %}
{%- for vip in network.primary.vips.apps | default([]) %}
! ping -c 1 -W 1 "{{ vip }}" &>/dev/null && pass "Apps VIP {{ vip }} not in use" || warn "Apps VIP {{ vip }} already in use"
{%- endfor %}
{%- endif %}
{%- if network.proxy is defined and network.proxy.httpProxy is defined %}

section "Proxy"
curl -s --proxy "{{ network.proxy.httpProxy }}" --connect-timeout 5 -o /dev/null https://quay.io && pass "proxy {{ network.proxy.httpProxy }} reachable" || warn "proxy {{ network.proxy.httpProxy }} not reachable"
{%- endif %}

# ── NTP ───────────────────────────────────
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

# ── REGISTRY ──────────────────────────────
{%- if account is defined and account.pullSecret is defined or cluster.mirrors is defined %}

section "Registry"
{%- if account is defined and account.pullSecret is defined %}
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
{%- set checked = [] -%}
{%- for mirror in cluster.mirrors | default([]) -%}
{%- for m in mirror.mirrors %}{% set host = m.split('/')[0] %}{% if host not in checked %}{% set _ = checked.append(host) %}
check_registry "{{ host }}"
{%- endif %}{% endfor %}{% endfor %}
{%- else %}
for registry in quay.io registry.redhat.io; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    [[ "$code" =~ ^(200|401|403)$ ]] && pass "$registry reachable" || warn "$registry HTTP $code"
done
{%- endif %}
{%- endif %}

# ── BMC ───────────────────────────────────
{%- for name, host in (hosts | default({})).items() if host.bmc is defined and host.bmc.address is defined %}
{%- if loop.first %}

section "BMC"
{%- endif %}
ping -c 1 -W 2 "{{ host.bmc.address }}" &>/dev/null && pass "{{ name }} BMC ({{ host.bmc.address }}) pingable" || warn "{{ name }} BMC ({{ host.bmc.address }}) not pingable"
{%- endfor %}
{%- for name, host in (hosts | default({})).items() if host.bmc is defined and host.bmc.address is defined %}
{%- if loop.first %}

section "Redfish"
{%- endif %}
code=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://{{ host.bmc.address }}/redfish/v1/" 2>/dev/null)
[[ "$code" =~ ^(200|401|403)$ ]] && pass "{{ name }} Redfish API responds" || warn "{{ name }} Redfish HTTP $code"
{%- endfor %}

echo ""
echo "═══════════════════════════════════════"
echo -e "  \033[32m✓\033[0m $PASS passed   \033[33m!\033[0m $WARN warnings"
echo "═══════════════════════════════════════"
