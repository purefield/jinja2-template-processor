{#- @meta
name: test-dns.sh
description: Shell script to verify DNS forward and reverse lookups for cluster
type: clusterfile
category: utility
requires:
  - cluster.name
  - network.domain
  - network.primary.vips
  - hosts
docs: https://docs.openshift.com/container-platform/latest/installing/installing_bare_metal/installing-bare-metal.html#installation-dns-user-infra_installing-bare-metal
-#}
echo; echo "****** Forward DNS lookup ******"
for h in {api,api-int,test.apps}.{{ cluster.name }}.{{ network.domain }}{% for name,host in hosts.items() %} {{name}}{% endfor %}; do echo -n "* $h -> "; dig +short $h | perl -pe 's/\.\n/ -> /'; echo; done

echo; echo "****** Reverse DNS lookup ******"
for h in {% if network.primary.vips %}{{ network.primary.vips.api|join(' ') }} {{ network.primary.vips.apps|join(' ') }}{% endif %}{% for name,host in hosts.items() %} {{ host.network.primary.address }}{% endfor %}; do echo -n "* $h -> "; dig +short -x $h; echo; done
