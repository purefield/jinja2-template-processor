{#- @meta
name: pre-check-registry.sh
description: Container registry connectivity verification
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
-#}
{% include 'includes/pre-check/common.sh.tpl' %}
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
# No pull secret configured, testing without auth
for registry in quay.io registry.redhat.io; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$registry/v2/" 2>/dev/null)
    [[ "$code" =~ ^(200|401|403)$ ]] && pass "$registry reachable" || warn "$registry HTTP $code"
done
{%- endif %}
{%- endif %}

summary
