#!/usr/bin/env python3
"""
Simple test runner for template tests without pytest dependency.
"""
import yaml
import os
import sys
import traceback

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from jinja2 import Environment, FileSystemLoader


class TestRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []

    def test(self, name, func):
        """Run a single test."""
        try:
            func()
            self.passed += 1
            print(f"  ✓ {name}")
        except AssertionError as e:
            self.failed += 1
            self.errors.append((name, str(e)))
            print(f"  ✗ {name}: {e}")
        except Exception as e:
            self.failed += 1
            self.errors.append((name, traceback.format_exc()))
            print(f"  ✗ {name}: {type(e).__name__}: {e}")

    def summary(self):
        print(f"\n{'='*60}")
        print(f"Results: {self.passed} passed, {self.failed} failed")
        if self.errors:
            print("\nFailures:")
            for name, error in self.errors:
                print(f"\n  {name}:")
                print(f"    {error[:200]}")
        return self.failed == 0


def create_template_env():
    """Create Jinja2 environment with custom filters."""
    template_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'templates')
    includes_dir = os.path.join(template_dir, 'includes')

    env = Environment(loader=FileSystemLoader([template_dir, includes_dir]))

    def load_file(path):
        if not path or not isinstance(path, str):
            return ""
        if 'pull-secret' in path:
            return '{"auths":{"registry.example.com":{"auth":"dGVzdDp0ZXN0"}}}'
        if 'id_rsa.pub' in path:
            return 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... test@example.com'
        if 'ca-bundle' in path or 'trustBundle' in path:
            return '-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----'
        if 'password' in path:
            return 'secret-password-123'
        if 'credentials' in path:
            if 'aws' in path:
                return '[default]\naws_access_key_id = AKIAIOSFODNN7EXAMPLE\naws_secret_access_key = wJalrXUtnFEMI'
            if 'azure' in path:
                return '{"subscriptionId":"sub-123","clientId":"client-456"}'
            if 'gcp' in path:
                return '{"type":"service_account","project_id":"my-project"}'
            return 'api-key-12345'
        return ""

    def base64encode(s):
        import base64
        if isinstance(s, str):
            s = s.encode("utf-8")
        return base64.b64encode(s).decode("utf-8")

    env.globals["load_file"] = load_file
    env.filters["base64encode"] = base64encode
    return env


def base_cluster_data():
    return {
        'account': {'pullSecret': 'secrets/pull-secret.json'},
        'cluster': {
            'name': 'test-cluster',
            'version': '4.18.0',
            'sshKeys': ['secrets/id_rsa.pub']
        },
        'network': {
            'domain': 'example.com',
            'primary': {'subnet': '10.0.0.0/16', 'type': 'OVNKubernetes'},
            'cluster': {'subnet': '10.128.0.0/14', 'hostPrefix': 23},
            'service': {'subnet': '172.30.0.0/16'}
        },
        'hosts': {
            'control-0': {'role': 'control'},
            'control-1': {'role': 'control'},
            'control-2': {'role': 'control'},
            'worker-0': {'role': 'worker'},
            'worker-1': {'role': 'worker'},
        },
        'plugins': {}
    }


def vips_data():
    return {'subnet': '10.0.0.0/24', 'vips': {'api': ['10.0.0.100'], 'apps': ['10.0.0.101']}}


# Platform plugin data
PLATFORMS = {
    'aws': {
        'aws': {
            'region': 'us-east-1',
            'credentials': 'secrets/aws-credentials',
            'controlPlane': {'type': 'm6i.xlarge', 'zones': ['us-east-1a', 'us-east-1b']},
            'compute': {'type': 'm6i.large', 'zones': ['us-east-1a', 'us-east-1b']}
        }
    },
    'azure': {
        'azure': {
            'region': 'eastus',
            'credentials': 'secrets/azure-credentials.json',
            'baseDomainResourceGroupName': 'openshift-dns-rg',
            'cloudName': 'AzurePublicCloud',
            'controlPlane': {'type': 'Standard_D8s_v3', 'zones': ['1', '2']},
            'compute': {'type': 'Standard_D4s_v3', 'zones': ['1', '2']}
        }
    },
    'gcp': {
        'gcp': {
            'projectID': 'my-gcp-project',
            'region': 'us-central1',
            'credentials': 'secrets/gcp-credentials.json',
            'controlPlane': {'type': 'n2-standard-4', 'zones': ['us-central1-a']},
            'compute': {'type': 'n2-standard-4', 'zones': ['us-central1-a']}
        }
    },
    'vsphere': {
        'vsphere': {
            'vcenter': {
                'server': 'vcenter.example.com',
                'username': 'admin@vsphere.local',
                'password': 'secrets/vcenter-password.txt',
                'datacenter': 'DC1',
                'defaultDatastore': 'vsanDatastore',
                'cluster': 'Cluster1'
            },
            'network': 'VM Network',
            'cpus': 4, 'coresPerSocket': 4, 'memoryMiB': 16384, 'diskGiB': 120
        }
    },
    'openstack': {
        'openstack': {
            'cloud': 'mycloud',
            'externalNetwork': 'external-net',
            'apiFloatingIP': '192.168.1.100',
            'computeFlavor': 'm1.xlarge',
            'controlPlaneFlavor': 'm1.2xlarge'
        }
    },
    'ibmcloud': {
        'ibmcloud': {
            'region': 'us-south',
            'resourceGroupName': 'openshift-rg',
            'credentials': 'secrets/ibmcloud-apikey.txt',
            'controlPlane': {'type': 'bx2-8x32', 'zones': ['us-south-1']},
            'compute': {'type': 'bx2-4x16', 'zones': ['us-south-1']}
        }
    },
    'nutanix': {
        'nutanix': {
            'credentials': 'secrets/nutanix-credentials.json',
            'prismCentral': {
                'endpoint': {'address': 'prism-central.example.com', 'port': 9440},
                'username': 'admin@example.com',
                'password': 'secrets/nutanix-password.txt'
            },
            'prismElements': [{'name': 'PE1', 'endpoint': {'address': 'pe.example.com', 'port': 9440}, 'uuid': 'xxx'}],
            'subnetUUIDs': ['yyy'],
            'controlPlane': {'cpus': 4, 'coresPerSocket': 2, 'memoryMiB': 16384, 'osDisk': {'diskSizeGiB': 120}},
            'compute': {'cpus': 4, 'coresPerSocket': 2, 'memoryMiB': 16384, 'osDisk': {'diskSizeGiB': 120}}
        }
    }
}


def render_install_config(env, data):
    template = env.get_template('install-config.yaml.tpl')
    return yaml.safe_load(template.render(data))


def render_creds(env, data):
    template = env.get_template('creds.yaml.tpl')
    rendered = template.render(data)
    if not rendered.strip():
        return None
    return yaml.safe_load(rendered)


def main():
    print("Template Test Suite")
    print("="*60)

    env = create_template_env()
    runner = TestRunner()

    # --- Install Config Tests ---
    print("\n[Install Config Template Tests]")

    for platform, plugin_data in PLATFORMS.items():
        def test_platform(p=platform, pd=plugin_data):
            data = base_cluster_data()
            data['cluster']['platform'] = p
            data['plugins'] = pd
            if p in ['vsphere', 'openstack', 'nutanix', 'baremetal']:
                data['network']['primary'] = vips_data()

            result = render_install_config(env, data)

            assert result['metadata']['name'] == 'test-cluster', f"Wrong cluster name"
            assert result['baseDomain'] == 'example.com', f"Wrong baseDomain"
            assert p in result['platform'], f"Platform {p} not in result"

            if p not in ['baremetal', 'none']:
                assert 'platform' in result['controlPlane'], f"No controlPlane.platform for {p}"
                assert p in result['controlPlane']['platform'], f"controlPlane.platform.{p} missing"

        runner.test(f"install-config {platform}", test_platform)

    # Test baremetal
    def test_baremetal():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        result = render_install_config(env, data)
        assert 'baremetal' in result['platform']
        assert result['platform']['baremetal']['apiVIPs'] == ['10.0.0.100']
        assert 'platform' not in result['controlPlane']  # baremetal has no controlPlane.platform

    runner.test("install-config baremetal", test_baremetal)

    # Test none (SNO)
    def test_none_sno():
        data = base_cluster_data()
        data['cluster']['platform'] = 'none'
        data['hosts'] = {'sno': {'role': 'control', 'storage': {'os': '/dev/sda'}}}
        result = render_install_config(env, data)
        assert result['platform'] == {'none': {}}
        assert result['controlPlane']['replicas'] == 1
        assert result['compute'][0]['replicas'] == 0
        assert 'bootstrapInPlace' in result

    runner.test("install-config none (SNO)", test_none_sno)

    # Test default platform
    def test_default_platform():
        data = base_cluster_data()
        data['network']['primary'] = vips_data()
        # No platform set
        result = render_install_config(env, data)
        assert 'baremetal' in result['platform']

    runner.test("install-config default platform is baremetal", test_default_platform)

    # Test proxy
    def test_proxy():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        data['network']['proxy'] = {
            'httpProxy': 'http://proxy:8080',
            'httpsProxy': 'http://proxy:8080',
            'noProxy': '.local'
        }
        result = render_install_config(env, data)
        assert 'proxy' in result
        assert result['proxy']['httpProxy'] == 'http://proxy:8080'

    runner.test("install-config with proxy", test_proxy)

    # Test trust bundle
    def test_trust_bundle():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        data['network']['trustBundle'] = 'secrets/ca-bundle.pem'
        result = render_install_config(env, data)
        assert 'additionalTrustBundle' in result
        assert 'BEGIN CERTIFICATE' in result['additionalTrustBundle']

    runner.test("install-config with trustBundle", test_trust_bundle)

    # Test image content sources
    def test_mirrors():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        data['cluster']['mirrors'] = [
            {'source': 'quay.io', 'mirrors': ['registry.local/quay']}
        ]
        result = render_install_config(env, data)
        assert 'imageContentSources' in result
        assert result['imageContentSources'][0]['source'] == 'quay.io'

    runner.test("install-config with imageContentSources", test_mirrors)

    # Test credentials mode
    def test_credentials_mode():
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = PLATFORMS['aws']
        result = render_install_config(env, data)
        assert result.get('credentialsMode') == 'Manual'

    runner.test("install-config credentialsMode for cloud platforms", test_credentials_mode)

    # Test node counts
    def test_node_counts():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        data['hosts'] = {
            'ctrl-0': {'role': 'control'},
            'ctrl-1': {'role': 'control'},
            'ctrl-2': {'role': 'control'},
            'wkr-0': {'role': 'worker'},
            'wkr-1': {'role': 'worker'},
        }
        result = render_install_config(env, data)
        assert result['controlPlane']['replicas'] == 3
        assert result['compute'][0]['replicas'] == 2

    runner.test("install-config node counts", test_node_counts)

    # --- Credentials Tests ---
    print("\n[Credentials Template Tests]")

    for platform in ['aws', 'azure', 'gcp', 'ibmcloud']:
        def test_creds(p=platform):
            data = base_cluster_data()
            data['cluster']['platform'] = p
            data['plugins'] = PLATFORMS[p]
            result = render_creds(env, data)
            assert result is not None, f"No credentials for {p}"
            assert result['kind'] == 'Secret', f"Wrong kind for {p}"

        runner.test(f"creds {platform}", test_creds)

    # vSphere returns a List
    def test_vsphere_creds():
        data = base_cluster_data()
        data['cluster']['platform'] = 'vsphere'
        data['plugins'] = PLATFORMS['vsphere']
        data['network']['primary'] = vips_data()
        result = render_creds(env, data)
        assert result['kind'] == 'List'
        assert len(result['items']) == 2

    runner.test("creds vsphere (List)", test_vsphere_creds)

    # OpenStack
    def test_openstack_creds():
        data = base_cluster_data()
        data['cluster']['platform'] = 'openstack'
        data['plugins'] = PLATFORMS['openstack']
        data['network']['primary'] = vips_data()
        result = render_creds(env, data)
        assert result['kind'] == 'Secret'
        assert 'clouds.yaml' in result['stringData']

    runner.test("creds openstack", test_openstack_creds)

    # Nutanix
    def test_nutanix_creds():
        data = base_cluster_data()
        data['cluster']['platform'] = 'nutanix'
        data['plugins'] = PLATFORMS['nutanix']
        data['network']['primary'] = vips_data()
        result = render_creds(env, data)
        assert result['kind'] == 'Secret'
        assert result['metadata']['namespace'] == 'openshift-machine-api'

    runner.test("creds nutanix", test_nutanix_creds)

    # Baremetal - no creds
    def test_baremetal_no_creds():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        result = render_creds(env, data)
        assert result is None

    runner.test("creds baremetal (none)", test_baremetal_no_creds)

    # --- Platform Include Tests ---
    print("\n[Platform Include Tests]")

    platforms_with_includes = ['aws', 'azure', 'gcp', 'vsphere', 'openstack', 'ibmcloud', 'nutanix']
    includes = ['controlPlane.yaml.tpl', 'compute.yaml.tpl', 'platform.yaml.tpl', 'creds.yaml.tpl']

    for platform in platforms_with_includes:
        for include in includes:
            def test_include(p=platform, i=include):
                template_name = f'platforms/{p}/{i}'
                env.get_template(template_name)  # Should not raise

            runner.test(f"include {platform}/{include}", test_include)

    # baremetal and none only have platform.yaml.tpl
    def test_baremetal_include():
        env.get_template('platforms/baremetal/platform.yaml.tpl')

    runner.test("include baremetal/platform.yaml.tpl", test_baremetal_include)

    def test_none_include():
        env.get_template('platforms/none/platform.yaml.tpl')

    runner.test("include none/platform.yaml.tpl", test_none_include)

    # --- Edge Cases ---
    print("\n[Edge Case Tests]")

    # VIP as string
    def test_vip_string():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = {'subnet': '10.0.0.0/24', 'vips': {'api': '10.0.0.100', 'apps': '10.0.0.101'}}
        result = render_install_config(env, data)
        assert result['platform']['baremetal']['apiVIPs'] == ['10.0.0.100']

    runner.test("VIP as string (not list)", test_vip_string)

    # Dual-stack VIPs
    def test_dual_stack_vips():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = {
            'subnet': '10.0.0.0/24',
            'vips': {'api': ['10.0.0.100', 'fd00::100'], 'apps': ['10.0.0.101', 'fd00::101']}
        }
        result = render_install_config(env, data)
        assert len(result['platform']['baremetal']['apiVIPs']) == 2

    runner.test("Dual-stack VIPs", test_dual_stack_vips)

    # Master role alias
    def test_master_role():
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = vips_data()
        data['hosts'] = {'m0': {'role': 'master'}, 'm1': {'role': 'master'}, 'm2': {'role': 'master'}}
        result = render_install_config(env, data)
        assert result['controlPlane']['replicas'] == 3

    runner.test("master role alias for control", test_master_role)

    # Empty hosts
    def test_empty_hosts():
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = PLATFORMS['aws']
        data['hosts'] = {}
        result = render_install_config(env, data)
        assert result['controlPlane']['replicas'] == 0
        assert result['compute'][0]['replicas'] == 0

    runner.test("Empty hosts", test_empty_hosts)

    # Summary
    success = runner.summary()
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
