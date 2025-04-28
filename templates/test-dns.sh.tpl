echo; echo "****** Forward DNS lookup ******"
for h in {api,api-int,test.apps}.{{ cluster.name }}.{{ network.domain }}{% for name,host in hosts.items() %} {{name}}{% endfor %}; do echo -n "* $h -> "; dig +short $h; echo; done

echo; echo "****** Reverse DNS lookup ******"
for h in {% if network.vips and network.vips.api %}{{network.vips.api}} {{network.vips.apps}}{% endif %}{% for name,host in hosts.items() %} {{ host.network.primary.address }}{% endfor %}; do echo -n "* $h -> "; dig +short -x $h; echo; done
