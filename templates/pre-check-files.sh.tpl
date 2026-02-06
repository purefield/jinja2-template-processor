{#- @meta
name: pre-check-files.sh
description: Validate required files (pull secret, SSH keys, trust bundle, manifests)
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{% include 'includes/pre-check/common.sh.tpl' %}
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

summary
