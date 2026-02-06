{#- Pre-check body: container registry connectivity -#}
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
