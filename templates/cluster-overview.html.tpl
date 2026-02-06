{#- @meta
name: cluster-overview.html
description: Customer-facing cluster overview document (self-contained HTML)
type: clusterfile
category: documentation
platforms:
  - aws
  - azure
  - gcp
  - vsphere
  - openstack
  - ibmcloud
  - nutanix
  - baremetal
  - none
requires:
  - cluster.name
  - network.domain
relatedTemplates:
  - install-config.yaml.tpl
  - pre-check.sh.tpl
docs: https://docs.openshift.com/container-platform/latest/installing/index.html
-#}
{%- set controlHosts = hosts.values() | selectattr('role', 'in', ['control', 'master']) | list -%}
{%- set workerHosts  = hosts.values() | selectattr('role', 'equalto', 'worker') | list -%}
{%- set platform = cluster.platform | default('baremetal', true) -%}
{%- set platformNames = {
  'baremetal': 'Bare Metal (Agent-based)',
  'none': 'Single Node OpenShift',
  'aws': 'Amazon Web Services',
  'azure': 'Microsoft Azure',
  'gcp': 'Google Cloud Platform',
  'vsphere': 'VMware vSphere',
  'openstack': 'Red Hat OpenStack',
  'ibmcloud': 'IBM Cloud',
  'nutanix': 'Nutanix'
} -%}
{%- set detailedHosts = [] -%}
{%- set simpleHosts = [] -%}
{%- for name, host in hosts.items() -%}
{%- if host.network is defined and host.network.primary is defined and host.network.primary.address is defined -%}
{%- set _ = detailedHosts.append({'name': name, 'host': host}) -%}
{%- else -%}
{%- set _ = simpleHosts.append({'name': name, 'host': host}) -%}
{%- endif -%}
{%- endfor -%}
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{ cluster.name }}.{{ network.domain }}</title>
<style>
  :root {
    --bg: #fff;
    --fg: #1d1d1f;
    --muted: #6e6e73;
    --border: #d2d2d7;
    --accent: #0066cc;
    --code-bg: #f5f5f7;
    --section-bg: #fbfbfd;
    --red: #ee0000;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #1d1d1f;
      --fg: #f5f5f7;
      --muted: #a1a1a6;
      --border: #424245;
      --accent: #2997ff;
      --code-bg: #2c2c2e;
      --section-bg: #232325;
      --red: #ff453a;
    }
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    color: var(--fg);
    background: var(--bg);
    line-height: 1.5;
    max-width: 960px;
    margin: 0 auto;
    padding: 48px 24px;
    -webkit-font-smoothing: antialiased;
  }
  header { margin-bottom: 48px; }
  header h1 {
    font-size: 32px;
    font-weight: 700;
    letter-spacing: -0.5px;
    margin-bottom: 4px;
  }
  header p { color: var(--muted); font-size: 17px; }
  section { margin-bottom: 40px; }
  h2 {
    font-size: 22px;
    font-weight: 600;
    letter-spacing: -0.2px;
    margin-bottom: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border);
  }
  h3 {
    font-size: 15px;
    font-weight: 600;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin: 24px 0 10px;
  }
  h3:first-child { margin-top: 0; }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
    margin-bottom: 8px;
  }
  th {
    text-align: left;
    font-weight: 600;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--muted);
    padding: 8px 12px;
    border-bottom: 2px solid var(--border);
  }
  td {
    padding: 8px 12px;
    border-bottom: 1px solid var(--border);
    vertical-align: top;
  }
  td:first-child { font-weight: 500; white-space: nowrap; }
  tr:last-child td { border-bottom: none; }
  .kv td:first-child { color: var(--muted); width: 160px; }
  .kv td:last-child { font-family: "SF Mono", Menlo, monospace; font-size: 13px; }
  code {
    font-family: "SF Mono", Menlo, Consolas, monospace;
    font-size: 13px;
    background: var(--code-bg);
    padding: 2px 6px;
    border-radius: 4px;
  }
  .card {
    background: var(--section-bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 16px 20px;
    margin-bottom: 12px;
  }
  .card h4 {
    font-size: 15px;
    font-weight: 600;
    margin-bottom: 10px;
  }
  .card table { margin-bottom: 0; }
  .card td:first-child { width: 120px; }
  .callout {
    background: var(--code-bg);
    border-left: 3px solid var(--accent);
    padding: 12px 16px;
    border-radius: 0 6px 6px 0;
    font-size: 14px;
    margin: 12px 0;
  }
  .tag {
    display: inline-block;
    background: var(--code-bg);
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
    margin-right: 4px;
  }
  ul { list-style: none; padding: 0; }
  ul li { padding: 4px 0; font-size: 14px; }
  ul li::before { content: ""; }
  footer {
    margin-top: 48px;
    padding-top: 16px;
    border-top: 1px solid var(--border);
    color: var(--muted);
    font-size: 12px;
  }
  @media print {
    body { padding: 0; max-width: none; }
    .card { break-inside: avoid; }
  }
</style>
</head>
<body>

<header>
  <h1>{{ cluster.name }}.{{ network.domain }}</h1>
  <p>OpenShift Container Platform {{ cluster.version | default('4.x') }} on {{ platformNames[platform] | default(platform) }}</p>
</header>

<section>
  <h2>Cluster Identity</h2>
  <table class="kv">
    <tr><td>Cluster Name</td><td>{{ cluster.name }}</td></tr>
    <tr><td>Base Domain</td><td>{{ network.domain }}</td></tr>
    <tr><td>FQDN</td><td>{{ cluster.name }}.{{ network.domain }}</td></tr>
    <tr><td>Platform</td><td>{{ platformNames[platform] | default(platform) }}</td></tr>
    <tr><td>Version</td><td>{{ cluster.version | default('—') }}</td></tr>{% if cluster.arch is defined %}
    <tr><td>Architecture</td><td>{{ cluster.arch }}</td></tr>{% endif %}{% if cluster.location is defined %}
    <tr><td>Location</td><td>{{ cluster.location }}</td></tr>{% endif %}
  </table>
</section>

<section>
  <h2>Topology</h2>
  <table>
    <thead><tr><th>Role</th><th>Count</th></tr></thead>
    <tbody>
      <tr><td>Control Plane</td><td>{{ controlHosts | length }}</td></tr>
      <tr><td>Worker</td><td>{{ workerHosts | length }}</td></tr>
      <tr><td><strong>Total</strong></td><td><strong>{{ hosts | length }}</strong></td></tr>
    </tbody>
  </table>{% if controlHosts | length == 1 and workerHosts | length == 0 %}
  <div class="callout">Single Node OpenShift — control plane and workloads run on one node.</div>{% endif %}
</section>

<section>
  <h2>Network</h2>{% if network.primary is defined %}
  <h3>Primary</h3>
  <table class="kv">{% if network.primary.subnet is defined %}
    <tr><td>Machine Network</td><td>{{ network.primary.subnet }}</td></tr>{% endif %}{% if network.primary.gateway is defined %}
    <tr><td>Gateway</td><td>{{ network.primary.gateway }}</td></tr>{% endif %}
    <tr><td>Network Type</td><td>{{ network.primary.type | default('OVNKubernetes') }}</td></tr>{% if network.primary.mtu %}
    <tr><td>MTU</td><td>{{ network.primary.mtu }}</td></tr>{% endif %}{% if network.primary.bond %}
    <tr><td>Bond Mode</td><td>{{ network.primary.bond }}</td></tr>{% endif %}{% if network.primary.vlan %}
    <tr><td>VLAN ID</td><td>{{ network.primary.vlan }}</td></tr>{% endif %}
  </table>{% endif %}{% if network.cluster is defined %}
  <h3>Cluster Networks</h3>
  <table>
    <thead><tr><th>Network</th><th>CIDR</th><th>Details</th></tr></thead>
    <tbody>{% if network.cluster.subnet is defined %}
      <tr><td>Cluster (pods)</td><td><code>{{ network.cluster.subnet }}</code></td><td>hostPrefix: /{{ network.cluster.hostPrefix | default(23) }}</td></tr>{% endif %}{% if network.service is defined and network.service.subnet is defined %}
      <tr><td>Service</td><td><code>{{ network.service.subnet }}</code></td><td>—</td></tr>{% endif %}{% if network.primary is defined and network.primary.subnet is defined %}
      <tr><td>Machine</td><td><code>{{ network.primary.subnet }}</code></td><td>—</td></tr>{% endif %}
    </tbody>
  </table>{% endif %}{% if network.primary is defined and network.primary.vips is defined %}
  <h3>Virtual IPs</h3>
  <table>
    <thead><tr><th>Purpose</th><th>Address</th></tr></thead>
    <tbody>{% for vip in network.primary.vips.api | default([]) %}
      <tr><td>API</td><td><code>{{ vip }}</code></td></tr>{% endfor %}{% for vip in network.primary.vips.apps | default([]) %}
      <tr><td>Ingress (*.apps)</td><td><code>{{ vip }}</code></td></tr>{% endfor %}
    </tbody>
  </table>{% endif %}{% if network.nameservers is defined %}
  <h3>DNS</h3>
  <table class="kv">
    <tr><td>Nameservers</td><td>{% for ns in network.nameservers %}<code>{{ ns }}</code>{% if not loop.last %} {% endif %}{% endfor %}</td></tr>{% if network.dnsResolver is defined and network.dnsResolver.search is defined %}
    <tr><td>Search Domains</td><td>{% for s in network.dnsResolver.search %}<code>{{ s }}</code>{% if not loop.last %} {% endif %}{% endfor %}</td></tr>{% endif %}
  </table>{% endif %}{% if network.ntpservers is defined %}
  <h3>NTP</h3>
  <table class="kv">
    <tr><td>NTP Servers</td><td>{% for ntp in network.ntpservers %}<code>{{ ntp }}</code>{% if not loop.last %} {% endif %}{% endfor %}</td></tr>
  </table>{% endif %}{% if network.proxy is defined %}
  <h3>Proxy</h3>
  <table class="kv">
    <tr><td>HTTP</td><td>{{ network.proxy.httpProxy }}</td></tr>
    <tr><td>HTTPS</td><td>{{ network.proxy.httpsProxy }}</td></tr>
    <tr><td>No Proxy</td><td style="word-break:break-all">{{ network.proxy.noProxy }}</td></tr>
  </table>{% endif %}
</section>
{% if detailedHosts | length > 0 %}
<section>
  <h2>Hosts</h2>{% for item in detailedHosts %}
  <div class="card">
    <h4>{{ item.name }}</h4>
    <table class="kv">
      <tr><td>Role</td><td>{{ 'Control Plane' if item.host.role in ['control', 'master'] else 'Worker' }}</td></tr>
      <tr><td>IP Address</td><td>{{ item.host.network.primary.address }}</td></tr>{% if item.host.bmc is defined %}
      <tr><td>BMC</td><td>{{ item.host.bmc.address }} <span class="tag">{{ item.host.bmc.vendor }}{% if item.host.bmc.version is defined %} v{{ item.host.bmc.version }}{% endif %}</span></td></tr>{% endif %}{% if item.host.storage is defined and item.host.storage.os is defined %}
      <tr><td>Boot Disk</td><td>{% if item.host.storage.os is mapping %}{% for k, v in item.host.storage.os.items() %}{{ k }}: <code>{{ v }}</code>{% if not loop.last %}, {% endif %}{% endfor %}{% else %}<code>{{ item.host.storage.os }}</code>{% endif %}</td></tr>{% endif %}{% if item.host.network.interfaces is defined %}
      <tr><td>NICs</td><td>{% for iface in item.host.network.interfaces %}<code>{{ iface.name }}</code> <span class="tag">{{ iface.macAddress }}</span>{% if not loop.last %} {% endif %}{% endfor %}</td></tr>{% endif %}{% if item.host.network.primary.ports is defined %}
      <tr><td>Bond Ports</td><td>{% for p in item.host.network.primary.ports %}<code>{{ p }}</code>{% if not loop.last %}, {% endif %}{% endfor %}</td></tr>{% endif %}
    </table>
  </div>{% endfor %}
</section>
{% elif simpleHosts | length > 0 %}
<section>
  <h2>Hosts</h2>
  <table>
    <thead><tr><th>Hostname</th><th>Role</th></tr></thead>
    <tbody>{% for item in simpleHosts %}
      <tr><td>{{ item.name }}</td><td>{{ 'Control Plane' if item.host.role in ['control', 'master'] else 'Worker' }}</td></tr>{% endfor %}
    </tbody>
  </table>
</section>
{% endif %}{% if cluster.mirrors is defined and cluster.mirrors | length > 0 %}
<section>
  <h2>Registry Mirrors</h2>
  <table>
    <thead><tr><th>Source</th><th>Mirror</th></tr></thead>
    <tbody>{% for mirror in cluster.mirrors %}
      <tr><td><code>{{ mirror.source }}</code></td><td>{% for m in mirror.mirrors %}<code>{{ m }}</code>{% if not loop.last %}<br>{% endif %}{% endfor %}</td></tr>{% endfor %}
    </tbody>
  </table>
</section>
{% endif %}{% if network.trustBundle is defined %}
<section>
  <h2>Trust</h2>
  <table class="kv">
    <tr><td>CA Bundle</td><td>{{ network.trustBundle }}</td></tr>
  </table>
</section>
{% endif %}{% if cluster.manifests is defined and cluster.manifests | length > 0 %}
<section>
  <h2>Additional Manifests</h2>
  <table>
    <thead><tr><th>Name</th><th>File</th></tr></thead>
    <tbody>{% for manifest in cluster.manifests %}
      <tr><td><code>{{ manifest.name }}</code></td><td>{{ manifest.file }}</td></tr>{% endfor %}
    </tbody>
  </table>
</section>
{% endif %}
{%- set hasDnsRecords = (network.primary is defined and network.primary.vips is defined) or detailedHosts | length > 0 -%}
{% if hasDnsRecords %}
<section>
  <h2>DNS Records Required</h2>
  <p style="color:var(--muted);font-size:14px;margin-bottom:12px">Create these records before installation.</p>
  <table>
    <thead><tr><th>Record</th><th>Type</th><th>Value</th></tr></thead>
    <tbody>{% if network.primary is defined and network.primary.vips is defined %}{% for vip in network.primary.vips.api | default([]) %}
      <tr><td><code>api.{{ cluster.name }}.{{ network.domain }}</code></td><td>A</td><td><code>{{ vip }}</code></td></tr>
      <tr><td><code>api-int.{{ cluster.name }}.{{ network.domain }}</code></td><td>A</td><td><code>{{ vip }}</code></td></tr>{% endfor %}{% for vip in network.primary.vips.apps | default([]) %}
      <tr><td><code>*.apps.{{ cluster.name }}.{{ network.domain }}</code></td><td>A</td><td><code>{{ vip }}</code></td></tr>{% endfor %}{% endif %}{% for item in detailedHosts %}
      <tr><td><code>{{ item.name }}</code></td><td>A</td><td><code>{{ item.host.network.primary.address }}</code></td></tr>{% endfor %}
    </tbody>
  </table>
</section>
{% endif %}
<footer>Generated from clusterfile configuration. Verify all values before installation.</footer>

</body>
</html>
