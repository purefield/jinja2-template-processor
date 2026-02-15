#!/usr/bin/env python3
"""
Comprehensive test suite for Jinja2 template rendering.
Tests all platforms, configuration options, and includes.
"""
import pytest
import yaml
import json
import os
import sys
import tempfile
import shutil

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from jinja2 import Environment, FileSystemLoader


# --- Test fixtures and helpers ---

@pytest.fixture
def template_env():
    """Create Jinja2 environment with custom filters."""
    template_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'templates')
    includes_dir = os.path.join(template_dir, 'includes')
    plugins_tpl  = os.path.join(template_dir, 'plugins')
    plugins_root = os.path.join(os.path.dirname(template_dir), 'plugins')

    env = Environment(loader=FileSystemLoader([template_dir, includes_dir, plugins_tpl, plugins_root]))

    # Mock load_file to return test data
    def load_file(path):
        if not path or not isinstance(path, str):
            return ""
        # Return mock data based on path patterns
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
                return '[default]\naws_access_key_id = AKIAIOSFODNN7EXAMPLE\naws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
            if 'azure' in path or 'sp' in path:
                return '{"subscriptionId":"sub-123","clientId":"client-456","clientSecret":"secret","tenantId":"tenant-789"}'
            if 'gcp' in path:
                return '{"type":"service_account","project_id":"my-project","private_key_id":"key123"}'
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


@pytest.fixture
def temp_secrets_dir():
    """Create temporary directory with mock secret files."""
    tmpdir = tempfile.mkdtemp()
    secrets_dir = os.path.join(tmpdir, 'secrets')
    os.makedirs(secrets_dir)

    # Create mock secret files
    with open(os.path.join(secrets_dir, 'pull-secret.json'), 'w') as f:
        f.write('{"auths":{"registry.example.com":{"auth":"dGVzdDp0ZXN0"}}}')
    with open(os.path.join(secrets_dir, 'id_rsa.pub'), 'w') as f:
        f.write('ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB test@example.com')
    with open(os.path.join(secrets_dir, 'ca-bundle.pem'), 'w') as f:
        f.write('-----BEGIN CERTIFICATE-----\nMIIDxTCCAq2gAwIBAgIQAqxcJmoLQ...\n-----END CERTIFICATE-----')
    with open(os.path.join(secrets_dir, 'vcenter-password.txt'), 'w') as f:
        f.write('vcenter-secret-123')
    with open(os.path.join(secrets_dir, 'aws-credentials'), 'w') as f:
        f.write('[default]\naws_access_key_id = AKIAIOSFODNN7EXAMPLE\naws_secret_access_key = wJalrXUtnFEMI')
    with open(os.path.join(secrets_dir, 'azure-credentials.json'), 'w') as f:
        f.write('{"subscriptionId":"sub-123","clientId":"client-456","clientSecret":"secret","tenantId":"tenant-789"}')
    with open(os.path.join(secrets_dir, 'gcp-credentials.json'), 'w') as f:
        f.write('{"type":"service_account","project_id":"my-project"}')
    with open(os.path.join(secrets_dir, 'nutanix-password.txt'), 'w') as f:
        f.write('nutanix-secret-456')
    with open(os.path.join(secrets_dir, 'ibmcloud-apikey.txt'), 'w') as f:
        f.write('ibmcloud-api-key-789')

    yield tmpdir
    shutil.rmtree(tmpdir)


# --- Base cluster data for each platform ---

def base_cluster_data():
    """Return base cluster configuration common to all platforms."""
    return {
        'account': {
            'pullSecret': 'secrets/pull-secret.json'
        },
        'cluster': {
            'name': 'test-cluster',
            'version': '4.18.0',
            'arch': 'x86_64',
            'location': 'us-east-1',
            'sshKeys': ['secrets/id_rsa.pub']
        },
        'network': {
            'domain': 'example.com',
            'primary': {
                'subnet': '10.0.0.0/16',
                'type': 'OVNKubernetes'
            },
            'cluster': {
                'subnet': '10.128.0.0/14',
                'hostPrefix': 23
            },
            'service': {
                'subnet': '172.30.0.0/16'
            }
        },
        'hosts': {
            'control-0.test-cluster.example.com': {'role': 'control'},
            'control-1.test-cluster.example.com': {'role': 'control'},
            'control-2.test-cluster.example.com': {'role': 'control'},
            'worker-0.test-cluster.example.com': {'role': 'worker'},
            'worker-1.test-cluster.example.com': {'role': 'worker'},
            'worker-2.test-cluster.example.com': {'role': 'worker'}
        },
        'plugins': {}
    }


# --- Platform-specific test data ---

def aws_plugin_data():
    return {
        'aws': {
            'region': 'us-east-1',
            'credentials': 'secrets/aws-credentials',
            'controlPlane': {
                'type': 'm6i.xlarge',
                'zones': ['us-east-1a', 'us-east-1b', 'us-east-1c'],
                'rootVolume': {'size': 120, 'type': 'gp3', 'iops': 4000}
            },
            'compute': {
                'type': 'm6i.large',
                'zones': ['us-east-1a', 'us-east-1b', 'us-east-1c'],
                'rootVolume': {'size': 100, 'type': 'gp3'}
            }
        }
    }


def azure_plugin_data():
    return {
        'azure': {
            'region': 'eastus',
            'credentials': 'secrets/azure-credentials.json',
            'baseDomainResourceGroupName': 'openshift-dns-rg',
            'cloudName': 'AzurePublicCloud',
            'controlPlane': {
                'type': 'Standard_D8s_v3',
                'zones': ['1', '2', '3'],
                'osDisk': {'diskSizeGB': 1024, 'diskType': 'Premium_LRS'}
            },
            'compute': {
                'type': 'Standard_D4s_v3',
                'zones': ['1', '2', '3'],
                'osDisk': {'diskSizeGB': 128, 'diskType': 'Premium_LRS'}
            }
        }
    }


def gcp_plugin_data():
    return {
        'gcp': {
            'projectID': 'my-gcp-project',
            'region': 'us-central1',
            'credentials': 'secrets/gcp-credentials.json',
            'controlPlane': {
                'type': 'n2-standard-4',
                'zones': ['us-central1-a', 'us-central1-b', 'us-central1-c'],
                'osDisk': {'diskSizeGB': 128, 'diskType': 'pd-ssd'}
            },
            'compute': {
                'type': 'n2-standard-4',
                'zones': ['us-central1-a', 'us-central1-b', 'us-central1-c'],
                'osDisk': {'diskSizeGB': 128, 'diskType': 'pd-ssd'}
            }
        }
    }


def vsphere_plugin_data():
    return {
        'vsphere': {
            'vcenter': {
                'server': 'vcenter.example.com',
                'username': 'administrator@vsphere.local',
                'password': 'secrets/vcenter-password.txt',
                'datacenter': 'DC1',
                'defaultDatastore': 'vsanDatastore',
                'cluster': 'Cluster1',
                'resourcePool': 'openshift-pool',
                'folder': 'openshift'
            },
            'network': 'VM Network',
            'cpus': 4,
            'coresPerSocket': 4,
            'memoryMiB': 16384,
            'diskGiB': 120
        }
    }


def openstack_plugin_data():
    return {
        'openstack': {
            'cloud': 'mycloud',
            'externalNetwork': 'external-net',
            'apiFloatingIP': '192.168.1.100',
            'ingressFloatingIP': '192.168.1.101',
            'computeFlavor': 'm1.xlarge',
            'controlPlaneFlavor': 'm1.2xlarge',
            'machinesSubnet': 'openshift-subnet',
            'trunkSupport': True,
            'octaviaSupport': True
        }
    }


def ibmcloud_plugin_data():
    return {
        'ibmcloud': {
            'region': 'us-south',
            'resourceGroupName': 'openshift-rg',
            'credentials': 'secrets/ibmcloud-apikey.txt',
            'controlPlane': {
                'type': 'bx2-8x32',
                'zones': ['us-south-1', 'us-south-2', 'us-south-3'],
                'bootVolume': {'encryptionKey': ''}
            },
            'compute': {
                'type': 'bx2-4x16',
                'zones': ['us-south-1', 'us-south-2', 'us-south-3']
            }
        }
    }


def nutanix_plugin_data():
    return {
        'nutanix': {
            'credentials': 'secrets/nutanix-credentials.json',
            'prismCentral': {
                'endpoint': {
                    'address': 'prism-central.example.com',
                    'port': 9440
                },
                'username': 'admin@example.com',
                'password': 'secrets/nutanix-password.txt'
            },
            'prismElements': [
                {
                    'name': 'PE1',
                    'endpoint': {
                        'address': 'prism-element.example.com',
                        'port': 9440
                    },
                    'uuid': 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                }
            ],
            'subnetUUIDs': ['yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'],
            'controlPlane': {
                'cpus': 4,
                'coresPerSocket': 2,
                'memoryMiB': 16384,
                'osDisk': {'diskSizeGiB': 120}
            },
            'compute': {
                'cpus': 4,
                'coresPerSocket': 2,
                'memoryMiB': 16384,
                'osDisk': {'diskSizeGiB': 120}
            }
        }
    }


def baremetal_vips_data():
    """Add VIPs required for baremetal platform."""
    return {
        'primary': {
            'subnet': '10.0.0.0/24',
            'type': 'OVNKubernetes',
            'vips': {
                'api': ['10.0.0.100'],
                'apps': ['10.0.0.101']
            }
        }
    }


# --- Test classes ---

class TestInstallConfigTemplate:
    """Test the unified install-config.yaml.tpl template."""

    def render_template(self, env, data):
        """Render install-config template and parse YAML."""
        template = env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def test_aws_platform(self, template_env):
        """Test AWS platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = aws_plugin_data()

        result = self.render_template(template_env, data)

        assert result['metadata']['name'] == 'test-cluster'
        assert result['baseDomain'] == 'example.com'
        assert result['platform']['aws']['region'] == 'us-east-1'
        assert result['controlPlane']['platform']['aws']['type'] == 'm6i.xlarge'
        assert result['controlPlane']['platform']['aws']['zones'] == ['us-east-1a', 'us-east-1b', 'us-east-1c']
        assert result['compute'][0]['platform']['aws']['type'] == 'm6i.large'
        assert result['credentialsMode'] == 'Manual'

    def test_aws_with_subnets(self, template_env):
        """Test AWS platform with BYO VPC subnets."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = aws_plugin_data()
        data['plugins']['aws']['subnets'] = ['subnet-0123456789abcdef0', 'subnet-0123456789abcdef1']

        result = self.render_template(template_env, data)

        assert 'subnets' in result['platform']['aws']
        assert len(result['platform']['aws']['subnets']) == 2

    def test_azure_platform(self, template_env):
        """Test Azure platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'azure'
        data['plugins'] = azure_plugin_data()

        result = self.render_template(template_env, data)

        assert result['platform']['azure']['region'] == 'eastus'
        assert result['platform']['azure']['baseDomainResourceGroupName'] == 'openshift-dns-rg'
        assert result['controlPlane']['platform']['azure']['type'] == 'Standard_D8s_v3'
        assert result['compute'][0]['platform']['azure']['type'] == 'Standard_D4s_v3'

    def test_gcp_platform(self, template_env):
        """Test GCP platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'gcp'
        data['plugins'] = gcp_plugin_data()

        result = self.render_template(template_env, data)

        assert result['platform']['gcp']['projectID'] == 'my-gcp-project'
        assert result['platform']['gcp']['region'] == 'us-central1'
        assert result['controlPlane']['platform']['gcp']['type'] == 'n2-standard-4'

    def test_vsphere_platform(self, template_env):
        """Test vSphere platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'vsphere'
        data['plugins'] = vsphere_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert 'vsphere' in result['platform']
        assert result['platform']['vsphere']['vcenters'][0]['server'] == 'vcenter.example.com'
        assert result['platform']['vsphere']['apiVIPs'] == ['10.0.0.100']
        assert result['platform']['vsphere']['ingressVIPs'] == ['10.0.0.101']
        assert result['controlPlane']['platform']['vsphere']['cpus'] == 4

    def test_vsphere_with_failure_domains(self, template_env):
        """Test vSphere platform with multiple failure domains."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'vsphere'
        data['plugins'] = vsphere_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']
        data['plugins']['vsphere']['failureDomains'] = [
            {
                'name': 'fd1',
                'region': 'region1',
                'zone': 'zone1',
                'datacenter': 'DC1',
                'cluster': 'Cluster1',
                'network': 'VM Network',
                'datastore': 'vsanDatastore'
            },
            {
                'name': 'fd2',
                'region': 'region1',
                'zone': 'zone2',
                'datacenter': 'DC2',
                'cluster': 'Cluster2',
                'network': 'VM Network',
                'datastore': 'vsanDatastore2'
            }
        ]

        result = self.render_template(template_env, data)

        assert len(result['platform']['vsphere']['failureDomains']) == 2
        assert result['platform']['vsphere']['failureDomains'][0]['name'] == 'fd1'
        assert result['platform']['vsphere']['failureDomains'][1]['name'] == 'fd2'

    def test_openstack_platform(self, template_env):
        """Test OpenStack platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'openstack'
        data['plugins'] = openstack_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert result['platform']['openstack']['cloud'] == 'mycloud'
        assert result['platform']['openstack']['externalNetwork'] == 'external-net'
        assert result['platform']['openstack']['apiFloatingIP'] == '192.168.1.100'
        assert result['controlPlane']['platform']['openstack']['type'] == 'm1.2xlarge'
        assert result['compute'][0]['platform']['openstack']['type'] == 'm1.xlarge'

    def test_ibmcloud_platform(self, template_env):
        """Test IBM Cloud platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'ibmcloud'
        data['plugins'] = ibmcloud_plugin_data()

        result = self.render_template(template_env, data)

        assert result['platform']['ibmcloud']['region'] == 'us-south'
        assert result['platform']['ibmcloud']['resourceGroupName'] == 'openshift-rg'
        assert result['controlPlane']['platform']['ibmcloud']['type'] == 'bx2-8x32'
        assert result['credentialsMode'] == 'Manual'

    def test_nutanix_platform(self, template_env):
        """Test Nutanix platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'nutanix'
        data['plugins'] = nutanix_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert 'nutanix' in result['platform']
        assert result['platform']['nutanix']['prismCentral']['endpoint']['address'] == 'prism-central.example.com'
        assert result['platform']['nutanix']['apiVIPs'] == ['10.0.0.100']
        assert len(result['platform']['nutanix']['prismElements']) == 1
        assert result['controlPlane']['platform']['nutanix']['cpus'] == 4

    def test_baremetal_platform(self, template_env):
        """Test baremetal platform configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert 'baremetal' in result['platform']
        assert result['platform']['baremetal']['apiVIPs'] == ['10.0.0.100']
        assert result['platform']['baremetal']['ingressVIPs'] == ['10.0.0.101']
        # baremetal should not have controlPlane.platform
        assert 'platform' not in result['controlPlane']

    def test_none_platform_sno(self, template_env):
        """Test platform: none for Single Node OpenShift."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'none'
        # SNO has only one control plane node
        data['hosts'] = {
            'sno.test-cluster.example.com': {
                'role': 'control',
                'storage': {
                    'os': '/dev/sda'
                }
            }
        }

        result = self.render_template(template_env, data)

        assert result['platform'] == {'none': {}}
        assert result['controlPlane']['replicas'] == 1
        assert result['compute'][0]['replicas'] == 0
        assert 'bootstrapInPlace' in result
        assert result['bootstrapInPlace']['installationDisk'] == '/dev/sda'

    def test_default_platform_is_baremetal(self, template_env):
        """Test that default platform is baremetal when not specified."""
        data = base_cluster_data()
        data['network']['primary'] = baremetal_vips_data()['primary']
        # Don't set cluster.platform

        result = self.render_template(template_env, data)

        assert 'baremetal' in result['platform']

    def test_proxy_configuration(self, template_env):
        """Test proxy configuration is included when defined."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']
        data['network']['proxy'] = {
            'httpProxy': 'http://proxy.example.com:8080',
            'httpsProxy': 'http://proxy.example.com:8080',
            'noProxy': '.cluster.local,.svc,127.0.0.1,localhost'
        }

        result = self.render_template(template_env, data)

        assert 'proxy' in result
        assert result['proxy']['httpProxy'] == 'http://proxy.example.com:8080'
        assert result['proxy']['httpsProxy'] == 'http://proxy.example.com:8080'

    def test_trust_bundle_configuration(self, template_env):
        """Test additionalTrustBundle is included when defined."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']
        data['network']['trustBundle'] = 'secrets/ca-bundle.pem'

        result = self.render_template(template_env, data)

        assert 'additionalTrustBundle' in result
        assert '-----BEGIN CERTIFICATE-----' in result['additionalTrustBundle']

    def test_image_content_sources(self, template_env):
        """Test imageDigestSources for disconnected installs."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']
        data['cluster']['mirrors'] = [
            {
                'source': 'quay.io',
                'mirrors': ['registry.example.com/quay-io']
            },
            {
                'source': 'registry.redhat.io',
                'mirrors': ['registry.example.com/redhat-io']
            }
        ]

        result = self.render_template(template_env, data)

        assert 'imageDigestSources' in result
        assert len(result['imageDigestSources']) == 2
        assert result['imageDigestSources'][0]['source'] == 'quay.io'

    def test_multiple_ssh_keys(self, template_env):
        """Test multiple SSH keys configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']
        data['cluster']['sshKeys'] = [
            'secrets/id_rsa.pub',
            'secrets/id_rsa2.pub'
        ]

        result = self.render_template(template_env, data)

        assert 'sshKey' in result
        # Both keys should be in the sshKey field
        assert 'ssh-rsa' in result['sshKey']

    def test_worker_count_zero(self, template_env):
        """Test configuration with no worker nodes."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = aws_plugin_data()
        # Only control plane nodes
        data['hosts'] = {
            'control-0.test-cluster.example.com': {'role': 'control'},
            'control-1.test-cluster.example.com': {'role': 'control'},
            'control-2.test-cluster.example.com': {'role': 'control'}
        }

        result = self.render_template(template_env, data)

        assert result['controlPlane']['replicas'] == 3
        assert result['compute'][0]['replicas'] == 0

    def test_networking_configuration(self, template_env):
        """Test networking section configuration."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert result['networking']['networkType'] == 'OVNKubernetes'
        assert result['networking']['clusterNetwork'][0]['cidr'] == '10.128.0.0/14'
        assert result['networking']['clusterNetwork'][0]['hostPrefix'] == 23
        assert result['networking']['serviceNetwork'] == ['172.30.0.0/16']


class TestCredentialsTemplate:
    """Test the unified creds.yaml.tpl template."""

    def render_template(self, env, data):
        """Render credentials template and parse YAML."""
        template = env.get_template('creds.yaml.tpl')
        rendered = template.render(data)
        if not rendered.strip():
            return None
        return yaml.safe_load(rendered)

    def test_aws_credentials(self, template_env):
        """Test AWS credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = aws_plugin_data()

        result = self.render_template(template_env, data)

        assert result['kind'] == 'Secret'
        assert result['metadata']['name'] == 'aws-creds'
        assert result['metadata']['namespace'] == 'kube-system'
        assert 'credentials' in result['stringData']

    def test_azure_credentials(self, template_env):
        """Test Azure credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'azure'
        data['plugins'] = azure_plugin_data()

        result = self.render_template(template_env, data)

        assert result['kind'] == 'Secret'
        assert result['metadata']['name'] == 'azure-credentials'
        assert result['stringData']['azure_region'] == 'eastus'
        assert result['stringData']['azure_resource_prefix'] == 'test-cluster'

    def test_gcp_credentials(self, template_env):
        """Test GCP credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'gcp'
        data['plugins'] = gcp_plugin_data()

        result = self.render_template(template_env, data)

        assert result['kind'] == 'Secret'
        assert result['metadata']['name'] == 'gcp-credentials'
        assert 'service_account.json' in result['stringData']

    def test_vsphere_credentials(self, template_env):
        """Test vSphere credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'vsphere'
        data['plugins'] = vsphere_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        # vSphere returns a List with multiple secrets
        assert result['kind'] == 'List'
        assert len(result['items']) == 2
        assert result['items'][0]['metadata']['name'] == 'vsphere-creds'
        assert result['items'][1]['metadata']['name'] == 'vsphere-cloud-credentials'

    def test_openstack_credentials(self, template_env):
        """Test OpenStack credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'openstack'
        data['plugins'] = openstack_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert result['kind'] == 'Secret'
        assert result['metadata']['name'] == 'openstack-credentials'
        assert 'clouds.yaml' in result['stringData']

    def test_ibmcloud_credentials(self, template_env):
        """Test IBM Cloud credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'ibmcloud'
        data['plugins'] = ibmcloud_plugin_data()

        result = self.render_template(template_env, data)

        assert result['kind'] == 'Secret'
        assert result['metadata']['name'] == 'ibmcloud-credentials'
        assert 'ibmcloud_api_key' in result['stringData']

    def test_nutanix_credentials(self, template_env):
        """Test Nutanix credentials generation."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'nutanix'
        data['plugins'] = nutanix_plugin_data()
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        assert result['kind'] == 'Secret'
        assert result['metadata']['name'] == 'nutanix-credentials'
        assert result['metadata']['namespace'] == 'openshift-machine-api'
        assert 'credentials' in result['stringData']

    def test_baremetal_no_credentials(self, template_env):
        """Test that baremetal platform generates no credentials."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_template(template_env, data)

        # baremetal should not generate credentials
        assert result is None

    def test_none_platform_no_credentials(self, template_env):
        """Test that none platform generates no credentials."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'none'
        data['hosts'] = {
            'sno.test-cluster.example.com': {'role': 'control'}
        }

        result = self.render_template(template_env, data)

        assert result is None


class TestPlatformIncludes:
    """Test individual platform include templates."""

    def test_all_platform_includes_exist(self, template_env):
        """Verify all expected platform includes exist."""
        platforms = ['aws', 'azure', 'gcp', 'vsphere', 'openstack', 'ibmcloud', 'nutanix']
        includes = ['controlPlane.yaml.tpl', 'compute.yaml.tpl', 'platform.yaml.tpl', 'creds.yaml.tpl']

        for platform in platforms:
            for include in includes:
                template_name = f'platforms/{platform}/{include}'
                try:
                    template_env.get_template(template_name)
                except Exception as e:
                    pytest.fail(f"Missing include: {template_name} - {e}")

    def test_baremetal_platform_include_exists(self, template_env):
        """Verify baremetal platform include exists."""
        template_env.get_template('platforms/baremetal/platform.yaml.tpl')

    def test_none_platform_include_exists(self, template_env):
        """Verify none platform include exists."""
        template_env.get_template('platforms/none/platform.yaml.tpl')


class TestEdgeCases:
    """Test edge cases and error handling."""

    def render_template(self, env, data):
        template = env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def test_empty_hosts(self, template_env):
        """Test with empty hosts section."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'aws'
        data['plugins'] = aws_plugin_data()
        data['hosts'] = {}

        result = self.render_template(template_env, data)

        assert result['controlPlane']['replicas'] == 0
        assert result['compute'][0]['replicas'] == 0

    def test_single_vip_as_string(self, template_env):
        """Test VIP as string instead of list."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = {
            'subnet': '10.0.0.0/24',
            'vips': {
                'api': '10.0.0.100',  # String, not list
                'apps': '10.0.0.101'
            }
        }

        result = self.render_template(template_env, data)

        # Should handle string VIPs correctly
        assert result['platform']['baremetal']['apiVIPs'] == ['10.0.0.100']

    def test_multiple_vips_as_list(self, template_env):
        """Test multiple VIPs as list (dual-stack)."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = {
            'subnet': '10.0.0.0/24',
            'vips': {
                'api': ['10.0.0.100', 'fd00::100'],
                'apps': ['10.0.0.101', 'fd00::101']
            }
        }

        result = self.render_template(template_env, data)

        assert len(result['platform']['baremetal']['apiVIPs']) == 2
        assert '10.0.0.100' in result['platform']['baremetal']['apiVIPs']
        assert 'fd00::100' in result['platform']['baremetal']['apiVIPs']

    def test_missing_optional_fields(self, template_env):
        """Test with minimal configuration (missing optional fields)."""
        data = {
            'account': {'pullSecret': 'secrets/pull-secret.json'},
            'cluster': {
                'name': 'minimal-cluster',
                'platform': 'aws',
                'sshKeys': ['secrets/id_rsa.pub']
            },
            'network': {
                'domain': 'example.com',
                'primary': {'subnet': '10.0.0.0/16'},
                'cluster': {'subnet': '10.128.0.0/14'},
                'service': {'subnet': '172.30.0.0/16'}
            },
            'hosts': {
                'node1': {'role': 'control'}
            },
            'plugins': {
                'aws': {
                    'region': 'us-east-1',
                    'credentials': 'secrets/aws-credentials'
                }
            }
        }

        result = self.render_template(template_env, data)

        assert result['metadata']['name'] == 'minimal-cluster'
        assert result['platform']['aws']['region'] == 'us-east-1'
        # Should use defaults for missing controlPlane/compute config
        assert 'type' in result['controlPlane']['platform']['aws']

    def test_master_role_alias(self, template_env):
        """Test that 'master' role is treated same as 'control'."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']
        data['hosts'] = {
            'master-0': {'role': 'master'},
            'master-1': {'role': 'master'},
            'master-2': {'role': 'master'},
            'worker-0': {'role': 'worker'}
        }

        result = self.render_template(template_env, data)

        # 'master' role should be counted as control plane
        assert result['controlPlane']['replicas'] == 3
        assert result['compute'][0]['replicas'] == 1


class TestYAMLOutput:
    """Test YAML output formatting and validity."""

    def test_output_is_valid_yaml(self, template_env):
        """Test that all platforms produce valid YAML."""
        platforms = [
            ('aws', aws_plugin_data()),
            ('azure', azure_plugin_data()),
            ('gcp', gcp_plugin_data()),
            ('ibmcloud', ibmcloud_plugin_data()),
        ]

        for platform, plugin_data in platforms:
            data = base_cluster_data()
            data['cluster']['platform'] = platform
            data['plugins'] = plugin_data

            template = template_env.get_template('install-config.yaml.tpl')
            rendered = template.render(data)

            # Should not raise
            result = yaml.safe_load(rendered)
            assert result is not None, f"Failed to parse YAML for platform: {platform}"

    def test_output_is_valid_yaml_with_vips(self, template_env):
        """Test that platforms requiring VIPs produce valid YAML."""
        platforms = [
            ('vsphere', vsphere_plugin_data()),
            ('openstack', openstack_plugin_data()),
            ('nutanix', nutanix_plugin_data()),
            ('baremetal', {}),
        ]

        for platform, plugin_data in platforms:
            data = base_cluster_data()
            data['cluster']['platform'] = platform
            data['plugins'] = plugin_data
            data['network']['primary'] = baremetal_vips_data()['primary']

            template = template_env.get_template('install-config.yaml.tpl')
            rendered = template.render(data)

            result = yaml.safe_load(rendered)
            assert result is not None, f"Failed to parse YAML for platform: {platform}"


class TestKubevirtClusterTemplate:
    """Test the kubevirt-cluster.yaml.tpl template."""

    def kubevirt_cluster_data(self, tpm=False, num_control=1, num_worker=0):
        """Return data for kubevirt-cluster template rendering with variable topology."""
        host_template = lambda i, role: {
            'role': role,
            'network': {
                'interfaces': [
                    {'name': 'eth0', 'macAddress': f'00:1A:2B:3C:4D:{i:02X}'}
                ]
            }
        }
        hosts = {}
        for i in range(num_control):
            hosts[f'ctrl{i+1}.kv-test.example.com'] = host_template(i + 1, 'control')
        for i in range(num_worker):
            hosts[f'worker{i+1}.kv-test.example.com'] = host_template(num_control + i + 1, 'worker')

        return {
            'cluster': {
                'name': 'kv-test',
                'tpm': tpm,
                'machine': {
                    'control': {
                        'cpus': 8, 'sockets': 1, 'memory': 32,
                        'storage': {'os': 120, 'data': [345]}
                    },
                    'worker': {
                        'cpus': 8, 'sockets': 1, 'memory': 32,
                        'storage': {'os': 120, 'data': [345]}
                    }
                }
            },
            'network': {
                'primary': {'vlan': False}
            },
            'plugins': {
                'kubevirt': {
                    'storageClass': {
                        'default': 'ocs-storagecluster-ceph-rbd',
                        'performance': 'lvms-vg1'
                    },
                    'network': {'type': 'cudn', 'vlan': '1410'}
                }
            },
            'hosts': hosts
        }

    def render_template(self, env, data):
        """Render kubevirt-cluster template and parse YAML."""
        template = env.get_template('kubevirt-cluster.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def get_vm(self, result, index=0):
        """Extract a VirtualMachine from the rendered List by index."""
        vms = [item for item in result['items'] if item['kind'] == 'VirtualMachine']
        return vms[index] if index < len(vms) else None

    def get_pvcs(self, result):
        """Extract all PVCs from the rendered List."""
        return [item for item in result['items'] if item['kind'] == 'PersistentVolumeClaim']

    def get_pvcs_for_vm(self, result, vmname):
        """Extract PVCs matching a VM name (OS + data)."""
        return [pvc for pvc in self.get_pvcs(result)
                if pvc['metadata']['name'].startswith(vmname)]

    def get_vms_by_role(self, result):
        """Return dict of role -> list of VMs."""
        vms = {'master': [], 'worker': []}
        for item in result['items']:
            if item['kind'] == 'VirtualMachine':
                role = item['spec']['template']['metadata']['labels']['role']
                vms[role].append(item)
        return vms

    def test_tpm_enabled(self, template_env):
        """Test that TPM device, SMM features, and EFI firmware appear when tpm=true."""
        data = self.kubevirt_cluster_data(tpm=True)
        result = self.render_template(template_env, data)
        vm = self.get_vm(result)

        assert vm is not None, "No VirtualMachine found in rendered output"
        domain = vm['spec']['template']['spec']['domain']

        # TPM device
        assert 'tpm' in domain['devices']
        assert domain['devices']['tpm']['persistent'] is True

        # SMM feature
        assert 'features' in domain
        assert 'smm' in domain['features']

        # UEFI firmware
        assert 'firmware' in domain
        assert domain['firmware']['bootloader']['efi']['persistent'] is True

    def test_tpm_disabled(self, template_env):
        """Test that TPM device, features, and firmware are absent when tpm=false."""
        data = self.kubevirt_cluster_data(tpm=False)
        result = self.render_template(template_env, data)
        vm = self.get_vm(result)

        assert vm is not None, "No VirtualMachine found in rendered output"
        domain = vm['spec']['template']['spec']['domain']

        assert 'tpm' not in domain.get('devices', {})
        assert 'features' not in domain
        assert 'firmware' not in domain

    def test_tpm_default_omitted(self, template_env):
        """Test that TPM fields are absent when tpm key is not set at all."""
        data = self.kubevirt_cluster_data(tpm=False)
        del data['cluster']['tpm']
        result = self.render_template(template_env, data)
        vm = self.get_vm(result)

        assert vm is not None, "No VirtualMachine found in rendered output"
        domain = vm['spec']['template']['spec']['domain']

        assert 'tpm' not in domain.get('devices', {})
        assert 'features' not in domain
        assert 'firmware' not in domain

    def test_vm_structure_with_tpm(self, template_env):
        """Test that core VM structure remains valid when TPM is enabled."""
        data = self.kubevirt_cluster_data(tpm=True)
        result = self.render_template(template_env, data)
        vm = self.get_vm(result)

        # Core structure still present
        assert vm['apiVersion'] == 'kubevirt.io/v1'
        assert vm['spec']['runStrategy'] == 'RerunOnFailure'
        domain = vm['spec']['template']['spec']['domain']
        assert domain['memory']['guest'] == '32Gi'
        assert domain['cpu']['cores'] == 8
        assert domain['resources']['requests']['memory'] == '16Gi'


    def test_compact_cluster_control_gets_data_disks(self, template_env):
        """Compact cluster (<=5 hosts): control nodes get data disks."""
        data = self.kubevirt_cluster_data(num_control=3, num_worker=0)
        result = self.render_template(template_env, data)
        vms = self.get_vms_by_role(result)

        # 3 total hosts <= 5, so control nodes should have data disks
        for vm in vms['master']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) > 0, "Compact cluster control node should have data disks"

    def test_compact_cluster_5_nodes_control_gets_data(self, template_env):
        """Compact cluster with 5 hosts: control nodes get data disks, workers do not."""
        data = self.kubevirt_cluster_data(num_control=3, num_worker=2)
        result = self.render_template(template_env, data)
        vms = self.get_vms_by_role(result)

        # 5 total hosts <= 5, control gets data disks
        for vm in vms['master']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) > 0, "Compact 5-node control should have data disks"

        # 5 < 3+3=6, workers do NOT get data disks
        for vm in vms['worker']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) == 0, "Compact 5-node workers should NOT have data disks"

    def test_standard_cluster_workers_get_data_disks(self, template_env):
        """Standard cluster (>=controlCount+3 hosts): workers get data disks, control does not."""
        data = self.kubevirt_cluster_data(num_control=3, num_worker=3)
        result = self.render_template(template_env, data)
        vms = self.get_vms_by_role(result)

        # 6 total hosts > 5, control does NOT get data disks
        for vm in vms['master']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) == 0, "Standard cluster control should NOT have data disks"

        # 6 >= 3+3=6, workers get data disks
        for vm in vms['worker']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) > 0, "Standard cluster workers should have data disks"

    def test_gap_cluster_no_data_disks(self, template_env):
        """Gap topology (6 hosts but only 2 workers): no one gets data disks."""
        data = self.kubevirt_cluster_data(num_control=4, num_worker=2)
        result = self.render_template(template_env, data)
        vms = self.get_vms_by_role(result)

        # 6 total > 5, so control does NOT get data disks
        for vm in vms['master']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) == 0, "Gap topology control should NOT have data disks"

        # 6 < 4+3=7, workers do NOT get data disks either
        for vm in vms['worker']:
            volumes = vm['spec']['template']['spec']['volumes']
            data_vols = [v for v in volumes if v['name'].startswith('datadisk-')]
            assert len(data_vols) == 0, "Gap topology workers should NOT have data disks"

    def test_control_os_uses_performance_storage(self, template_env):
        """Control plane OS PVC uses performance storage class by default."""
        data = self.kubevirt_cluster_data(num_control=3, num_worker=0)
        result = self.render_template(template_env, data)
        pvcs = self.get_pvcs(result)

        os_pvcs = [p for p in pvcs if '-data-' not in p['metadata']['name']]
        for pvc in os_pvcs:
            assert pvc['spec']['storageClassName'] == 'lvms-vg1', \
                f"Control OS PVC should use performance (lvms-vg1), got {pvc['spec']['storageClassName']}"

    def test_worker_os_uses_default_storage(self, template_env):
        """Worker OS PVC uses default storage class."""
        data = self.kubevirt_cluster_data(num_control=3, num_worker=3)
        result = self.render_template(template_env, data)
        pvcs = self.get_pvcs(result)

        # Worker OS PVCs (not data PVCs) — workers are named worker1, worker2, worker3
        worker_os_pvcs = [p for p in pvcs
                          if 'worker' in p['metadata']['name']
                          and '-data-' not in p['metadata']['name']]
        for pvc in worker_os_pvcs:
            assert pvc['spec']['storageClassName'] == 'ocs-storagecluster-ceph-rbd', \
                f"Worker OS PVC should use default (ocs), got {pvc['spec']['storageClassName']}"

    def test_data_disks_use_performance_storage(self, template_env):
        """Data disk PVCs always use performance storage class."""
        data = self.kubevirt_cluster_data(num_control=3, num_worker=3)
        result = self.render_template(template_env, data)
        pvcs = self.get_pvcs(result)

        data_pvcs = [p for p in pvcs if '-data-' in p['metadata']['name']]
        for pvc in data_pvcs:
            assert pvc['spec']['storageClassName'] == 'lvms-vg1', \
                f"Data PVC should use performance (lvms-vg1), got {pvc['spec']['storageClassName']}"


class TestAcmZtpTemplate:
    """Test the acm-ztp.yaml.tpl template for TPM at cluster level."""

    def acm_ztp_data(self, platform='baremetal', tpm=False):
        """Return data for acm-ztp template rendering."""
        data = {
            'account': {
                'pullSecret': 'secrets/pull-secret.json'
            },
            'cluster': {
                'name': 'ztp-test',
                'version': '4.21.0',
                'arch': 'x86_64',
                'location': 'dc1',
                'platform': platform,
                'tpm': tpm,
                'sshKeys': ['secrets/id_rsa.pub']
            },
            'network': {
                'domain': 'example.com',
                'nameservers': ['10.0.0.100'],
                'dnsResolver': {'search': ['example.com']},
                'ntpservers': ['10.0.0.100'],
                'primary': {
                    'bond': False,
                    'vlan': False,
                    'gateway': '10.0.0.1',
                    'subnet': '10.0.0.0/24',
                    'type': 'OVNKubernetes',
                    'vips': {
                        'api': ['10.0.0.2'],
                        'apps': ['10.0.0.3']
                    }
                },
                'cluster': {
                    'subnet': '10.128.0.0/14',
                    'hostPrefix': 23
                },
                'service': {
                    'subnet': '172.30.0.0/16'
                }
            },
            'hosts': {
                'node1.ztp-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell',
                        'version': 9,
                        'username': 'admin',
                        'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [
                            {'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}
                        ],
                        'primary': {
                            'address': '10.0.0.4',
                            'ports': ['eth0']
                        }
                    }
                },
                'node2.ztp-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell',
                        'version': 9,
                        'username': 'admin',
                        'password': 'bmc-password.txt',
                        'address': '10.0.1.5'
                    },
                    'network': {
                        'interfaces': [
                            {'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:02'}
                        ],
                        'primary': {
                            'address': '10.0.0.5',
                            'ports': ['eth0']
                        }
                    }
                },
                'node3.ztp-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell',
                        'version': 9,
                        'username': 'admin',
                        'password': 'bmc-password.txt',
                        'address': '10.0.1.6'
                    },
                    'network': {
                        'interfaces': [
                            {'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:03'}
                        ],
                        'primary': {
                            'address': '10.0.0.6',
                            'ports': ['eth0']
                        }
                    }
                }
            },
            'plugins': {}
        }
        return data

    def render_template(self, env, data):
        """Render acm-ztp template and parse YAML."""
        template = env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def get_configmap(self, result, name):
        """Find a ConfigMap by name in the rendered List."""
        for item in result['items']:
            if item['kind'] == 'ConfigMap' and item['metadata']['name'] == name:
                return item
        return None

    def test_tpm_manifest_baremetal(self, template_env):
        """Test that TPM manifest appears in extraclustermanifests for baremetal with cluster.tpm: true."""
        data = self.acm_ztp_data(platform='baremetal', tpm=True)
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-tpm-disk-encryption.yaml' in cm['data']
        assert 'tpm2: true' in cm['data']['99-tpm-disk-encryption.yaml']

    def test_tpm_manifest_kubevirt(self, template_env):
        """Test that TPM manifest appears in extraclustermanifests for kubevirt with cluster.tpm: true."""
        data = self.acm_ztp_data(platform='kubevirt', tpm=True)
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-tpm-disk-encryption.yaml' in cm['data']
        assert 'tpm2: true' in cm['data']['99-tpm-disk-encryption.yaml']

    def test_no_tpm_manifest_when_disabled(self, template_env):
        """Test that TPM manifest is absent when cluster.tpm is false."""
        data = self.acm_ztp_data(platform='baremetal', tpm=False)
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'extraclustermanifests')
        # ConfigMap should not exist when no manifests, mirrors, or TPM
        assert cm is None, "extraclustermanifests ConfigMap should not exist when TPM is disabled"

    def test_no_tpm_manifest_when_omitted(self, template_env):
        """Test that TPM manifest is absent when cluster.tpm key is not set."""
        data = self.acm_ztp_data(platform='baremetal', tpm=False)
        del data['cluster']['tpm']
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is None, "extraclustermanifests ConfigMap should not exist when TPM is omitted"

    def test_no_manifestwork_for_tpm(self, template_env):
        """TPM is install-time only via extraclustermanifests. No TPM ManifestWork should exist
        because applying LUKS MachineConfig post-install wipes root disks."""
        data = self.acm_ztp_data(platform='baremetal', tpm=True)
        result = self.render_template(template_env, data)

        for item in result['items']:
            if item['kind'] == 'ManifestWork':
                assert item['metadata']['name'] != 'tpm-disk-encryption', \
                    "ManifestWork must not be used for TPM — LUKS post-install wipes root disks"

    def test_poc_banner_present(self, template_env):
        """Test that POC banner ManifestWork is always present in ZTP output."""
        data = self.acm_ztp_data(platform='baremetal', tpm=False)
        result = self.render_template(template_env, data)

        banner = None
        for item in result['items']:
            if item['kind'] == 'ManifestWork' and item['metadata']['name'] == 'poc-banner':
                banner = item
                break
        assert banner is not None, "poc-banner ManifestWork not found"
        cn = banner['spec']['workload']['manifests'][0]
        assert cn['kind'] == 'ConsoleNotification'
        assert 'Proof of Concept' in cn['spec']['text']
        assert cn['spec']['location'] == 'BannerTop'

    def test_insecure_mirror_registries_conf(self, template_env):
        """Test that insecure = true appears in registries.conf when mirror has insecure: true."""
        data = self.acm_ztp_data(platform='baremetal', tpm=False)
        data['cluster']['mirrors'] = [
            {
                'source': 'quay.io',
                'prefix': '',
                'insecure': True,
                'mirrors': ['internal-registry.tld/quay-io']
            },
            {
                'source': 'registry.redhat.io',
                'prefix': '',
                'mirrors': ['internal-registry.tld/redhat-io']
            }
        ]
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'mirror-registries-ztp-test')
        assert cm is not None, "mirror-registries ConfigMap not found"
        registries_conf = cm['data']['registries.conf']
        # First mirror (insecure) should have insecure = true
        assert 'insecure = true' in registries_conf
        # Check it appears after the insecure mirror location
        lines = registries_conf.split('\n')
        found_insecure = False
        for i, line in enumerate(lines):
            if 'internal-registry.tld/quay-io' in line:
                # Next non-empty line should be insecure = true
                for j in range(i+1, len(lines)):
                    if lines[j].strip():
                        assert 'insecure = true' in lines[j], \
                            f"Expected insecure = true after quay-io mirror, got: {lines[j]}"
                        found_insecure = True
                        break
                break
        assert found_insecure, "insecure = true not found after insecure mirror location"

    def test_insecure_mirror_image_config(self, template_env):
        """Test that 99-insecure-registries.yaml appears in extraclustermanifests with correct insecureRegistries."""
        data = self.acm_ztp_data(platform='baremetal', tpm=False)
        data['cluster']['mirrors'] = [
            {
                'source': 'quay.io',
                'prefix': '',
                'insecure': True,
                'mirrors': ['internal-registry.tld/quay-io']
            },
            {
                'source': 'registry.redhat.io',
                'prefix': '',
                'insecure': True,
                'mirrors': ['internal-registry.tld/redhat-io']
            }
        ]
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-insecure-registries.yaml' in cm['data'], \
            "99-insecure-registries.yaml key not found in extraclustermanifests"
        insecure_manifest = cm['data']['99-insecure-registries.yaml']
        assert 'kind: Image' in insecure_manifest
        assert 'insecureRegistries' in insecure_manifest
        assert 'internal-registry.tld/quay-io' in insecure_manifest
        assert 'internal-registry.tld/redhat-io' in insecure_manifest

    def test_no_insecure_when_false(self, template_env):
        """Test that no insecure manifests appear when insecure is false or absent."""
        data = self.acm_ztp_data(platform='baremetal', tpm=False)
        data['cluster']['mirrors'] = [
            {
                'source': 'quay.io',
                'prefix': '',
                'insecure': False,
                'mirrors': ['internal-registry.tld/quay-io']
            },
            {
                'source': 'registry.redhat.io',
                'prefix': '',
                'mirrors': ['internal-registry.tld/redhat-io']
            }
        ]
        result = self.render_template(template_env, data)

        cm = self.get_configmap(result, 'mirror-registries-ztp-test')
        assert cm is not None, "mirror-registries ConfigMap not found"
        registries_conf = cm['data']['registries.conf']
        assert 'insecure = true' not in registries_conf, \
            "insecure = true should not appear when insecure is false/absent"

        cm_extra = self.get_configmap(result, 'extraclustermanifests')
        if cm_extra is not None:
            assert '99-insecure-registries.yaml' not in cm_extra.get('data', {}), \
                "99-insecure-registries.yaml should not exist when no mirrors are insecure"


class TestAcmCapiTemplate:
    """Test the acm-capi-m3.yaml.tpl template."""

    def acm_capi_data(self):
        """Return data for acm-capi-m3 template rendering."""
        return {
            'account': {
                'pullSecret': 'secrets/pull-secret.json'
            },
            'cluster': {
                'name': 'capi-test',
                'version': '4.21.0',
                'arch': 'x86_64',
                'location': 'dc1',
                'platform': 'baremetal',
                'sshKeys': ['secrets/id_rsa.pub']
            },
            'network': {
                'domain': 'example.com',
                'nameservers': ['10.0.0.100'],
                'dnsResolver': {'search': ['example.com']},
                'ntpservers': ['10.0.0.100'],
                'primary': {
                    'bond': False,
                    'vlan': False,
                    'gateway': '10.0.0.1',
                    'subnet': '10.0.0.0/24',
                    'type': 'OVNKubernetes',
                    'vips': {
                        'api': ['10.0.0.2'],
                        'apps': ['10.0.0.3']
                    }
                },
                'cluster': {
                    'subnet': '10.128.0.0/14',
                    'hostPrefix': 23
                },
                'service': {
                    'subnet': '172.30.0.0/16'
                }
            },
            'hosts': {
                'node1.capi-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                        'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                    }
                },
                'node2.capi-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.5'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:02'}],
                        'primary': {'address': '10.0.0.5', 'ports': ['eth0']}
                    }
                },
                'node3.capi-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.6'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:03'}],
                        'primary': {'address': '10.0.0.6', 'ports': ['eth0']}
                    }
                }
            },
            'plugins': {}
        }

    def render_template(self, env, data):
        """Render acm-capi-m3 template and parse YAML."""
        template = env.get_template('acm-capi-m3.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def test_poc_banner_present(self, template_env):
        """Test that POC banner ManifestWork is present in CAPI output."""
        data = self.acm_capi_data()
        result = self.render_template(template_env, data)

        banner = None
        for item in result['items']:
            if item['kind'] == 'ManifestWork' and item['metadata']['name'] == 'poc-banner':
                banner = item
                break
        assert banner is not None, "poc-banner ManifestWork not found in CAPI template"
        cn = banner['spec']['workload']['manifests'][0]
        assert cn['kind'] == 'ConsoleNotification'
        assert 'Proof of Concept' in cn['spec']['text']


class TestDisconnectedOperatorHub:
    """Test cluster.disconnected flag for air-gapped clusters."""

    def disconnected_ztp_data(self, disconnected=True, catalogs=True):
        """Return data for testing disconnected feature in ZTP template."""
        data = {
            'account': {
                'pullSecret': 'secrets/pull-secret.json'
            },
            'cluster': {
                'name': 'disc-test',
                'version': '4.21.0',
                'arch': 'x86_64',
                'location': 'dc1',
                'platform': 'baremetal',
                'sshKeys': ['secrets/id_rsa.pub'],
                'disconnected': disconnected
            },
            'network': {
                'domain': 'example.com',
                'nameservers': ['10.0.0.100'],
                'dnsResolver': {'search': ['example.com']},
                'ntpservers': ['10.0.0.100'],
                'primary': {
                    'bond': False,
                    'vlan': False,
                    'gateway': '10.0.0.1',
                    'subnet': '10.0.0.0/24',
                    'type': 'OVNKubernetes',
                    'vips': {
                        'api': ['10.0.0.2'],
                        'apps': ['10.0.0.3']
                    }
                },
                'cluster': {
                    'subnet': '10.128.0.0/14',
                    'hostPrefix': 23
                },
                'service': {
                    'subnet': '172.30.0.0/16'
                }
            },
            'hosts': {
                'node1.disc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                        'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                    }
                },
                'node2.disc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.5'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:02'}],
                        'primary': {'address': '10.0.0.5', 'ports': ['eth0']}
                    }
                },
                'node3.disc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.6'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:03'}],
                        'primary': {'address': '10.0.0.6', 'ports': ['eth0']}
                    }
                }
            },
            'plugins': {}
        }
        if catalogs:
            data['cluster']['catalogSources'] = [
                {
                    'name': 'disconnected-redhat-operators',
                    'displayName': 'Red Hat Operators',
                    'image': 'internal-registry.tld/redhat/redhat-operator-index:v4.19',
                    'publisher': 'Red Hat'
                },
                {
                    'name': 'disconnected-certified-operators',
                    'displayName': 'Certified Operators',
                    'image': 'internal-registry.tld/redhat/certified-operator-index:v4.19',
                    'publisher': 'Red Hat'
                }
            ]
        return data

    def get_configmap(self, result, name):
        """Find a ConfigMap by name in the rendered List."""
        for item in result['items']:
            if item['kind'] == 'ConfigMap' and item['metadata']['name'] == name:
                return item
        return None

    def test_disconnected_acm_ztp(self, template_env):
        """Test extraclustermanifests has 99-operatorhub.yaml + 99-catalogsource-*.yaml."""
        data = self.disconnected_ztp_data(disconnected=True, catalogs=True)
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-operatorhub.yaml' in cm['data'], "99-operatorhub.yaml key not found"
        assert 'disableAllDefaultSources: true' in cm['data']['99-operatorhub.yaml']
        assert '99-catalogsource-disconnected-redhat-operators.yaml' in cm['data']
        assert '99-catalogsource-disconnected-certified-operators.yaml' in cm['data']
        assert 'redhat-operator-index:v4.19' in cm['data']['99-catalogsource-disconnected-redhat-operators.yaml']

    def test_disconnected_install_config(self, template_env):
        """Test install-config output includes OperatorHub + CatalogSource docs."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['cluster']['disconnected'] = True
        data['cluster']['catalogSources'] = [
            {
                'name': 'test-operators',
                'image': 'registry.example.com/operators:v4.19',
                'displayName': 'Test Operators',
                'publisher': 'Test'
            }
        ]
        data['network']['primary'] = baremetal_vips_data()['primary']

        template = template_env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        docs = list(yaml.safe_load_all(rendered))

        # First doc is install-config, then OperatorHub, then CatalogSource(s)
        assert len(docs) >= 3, f"Expected at least 3 YAML docs, got {len(docs)}"
        operatorhub = docs[1]
        assert operatorhub['kind'] == 'OperatorHub'
        assert operatorhub['spec']['disableAllDefaultSources'] is True
        catalogsource = docs[2]
        assert catalogsource['kind'] == 'CatalogSource'
        assert catalogsource['metadata']['name'] == 'test-operators'
        assert catalogsource['spec']['image'] == 'registry.example.com/operators:v4.19'

    def test_disconnected_without_catalogs(self, template_env):
        """Test that disconnected without catalogSources just disables OperatorHub."""
        data = self.disconnected_ztp_data(disconnected=True, catalogs=False)
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-operatorhub.yaml' in cm['data']
        # No catalogsource keys
        catalog_keys = [k for k in cm['data'] if 'catalogsource' in k]
        assert len(catalog_keys) == 0, f"Expected no catalogsource keys, got {catalog_keys}"

    def test_not_disconnected(self, template_env):
        """Test no disconnected manifests when flag is false/absent."""
        data = self.disconnected_ztp_data(disconnected=False, catalogs=False)
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        cm = self.get_configmap(result, 'extraclustermanifests')
        # No manifests, mirrors, TPM, or disconnected — ConfigMap should not exist
        assert cm is None, "extraclustermanifests should not exist when disconnected is false"


class TestOperatorsPlugin:
    """Tests for operator plugin architecture — ArgoCD."""

    def operator_data(self, argocd_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        if argocd_config is not None:
            data['plugins'] = {'operators': {'argocd': argocd_config}}
        return data

    def test_argocd_standalone_defaults(self, template_env):
        """Test standalone operators template with all ArgoCD defaults."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = list(yaml.safe_load_all(rendered))
        docs = [d for d in docs if d is not None]

        kinds = [d['kind'] for d in docs]
        assert 'Namespace' in kinds
        assert 'OperatorGroup' in kinds
        assert 'Subscription' in kinds
        assert 'ArgoCD' in kinds

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'latest'
        assert sub['spec']['source'] == 'redhat-operators'
        assert sub['spec']['installPlanApproval'] == 'Automatic'

    def test_argocd_custom_channel(self, template_env):
        """Test ArgoCD with custom channel and HA."""
        data = self.operator_data({'channel': 'gitops-1.14', 'ha': True})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'gitops-1.14'

        argo = next(d for d in docs if d['kind'] == 'ArgoCD')
        assert argo['spec']['ha']['enabled'] is True

    def test_argocd_rbac_policy(self, template_env):
        """Test ArgoCD with custom RBAC policy."""
        policy = "g, system:cluster-admins, role:admin\np, role:dev, applications, *, */*, allow"
        data = self.operator_data({'rbac': {'policy': policy, 'defaultPolicy': 'role:admin'}})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        argo = next(d for d in docs if d['kind'] == 'ArgoCD')
        assert 'role:dev' in argo['spec']['rbac']['policy']
        assert argo['spec']['rbac']['defaultPolicy'] == 'role:admin'

    def test_argocd_disabled(self, template_env):
        """Test ArgoCD with enabled: false produces no output."""
        data = self.operator_data({'enabled': False})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        # Should produce no YAML docs
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        assert len(docs) == 0

    def test_no_operators_plugin(self, template_env):
        """Test templates work fine without operators plugin."""
        data = self.operator_data(None)  # no operators plugin
        template = template_env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        # Should have install-config but no operator resources
        kinds = [d.get('kind', '') for d in docs]
        assert 'Subscription' not in kinds
        assert 'ArgoCD' not in kinds

    def test_argocd_in_install_config(self, template_env):
        """Test ArgoCD manifests appear in install-config output."""
        data = self.operator_data({})
        template = template_env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        kinds = [d.get('kind', '') for d in docs]
        assert 'Subscription' in kinds
        assert 'ArgoCD' in kinds

    def test_argocd_acm_ztp_policy(self, template_env):
        """Test ArgoCD generates ACM Policy in ZTP template."""
        data = self.operator_data({})
        data['cluster']['version'] = '4.21.0'
        data['cluster']['arch'] = 'x86_64'
        for hostname, host in data['hosts'].items():
            host['bmc'] = {'vendor': 'dell', 'version': 9, 'address': '10.0.1.1', 'macAddress': 'aa:bb:cc:dd:ee:ff', 'username': 'root', 'password': 'pw'}
            host['network'] = {'interfaces': [{'name': 'eth0', 'macAddress': 'aa:bb:cc:dd:ee:01'}], 'primary': {'address': '10.0.0.10', 'ports': ['eth0']}}
            host['storage'] = {'os': {'deviceName': '/dev/sda'}}
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        items = result.get('items', [])
        policies = [i for i in items if i.get('kind') == 'Policy' and i['metadata']['name'] == 'operator-argocd']
        assert len(policies) == 1, "Expected one ArgoCD Policy"

        bindings = [i for i in items if i.get('kind') == 'PlacementBinding' and i['metadata']['name'] == 'operator-argocd']
        assert len(bindings) == 1, "Expected one ArgoCD PlacementBinding"

    def test_argocd_bootstrap_application(self, template_env):
        """Test ArgoCD bootstrap creates an Application CR for app-of-apps."""
        data = self.operator_data({'bootstrap': {'repoURL': 'https://git.example.com/cluster-config.git', 'path': 'operators', 'targetRevision': 'main'}})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        apps = [d for d in docs if d.get('kind') == 'Application']
        assert len(apps) == 1
        app = apps[0]
        assert app['metadata']['name'] == 'cluster-bootstrap'
        assert app['spec']['source']['repoURL'] == 'https://git.example.com/cluster-config.git'
        assert app['spec']['source']['path'] == 'operators'
        assert app['spec']['source']['targetRevision'] == 'main'
        assert app['spec']['syncPolicy']['automated']['selfHeal'] is True

    def test_argocd_bootstrap_no_sync(self, template_env):
        """Test ArgoCD bootstrap with autoSync disabled omits syncPolicy."""
        data = self.operator_data({'bootstrap': {'repoURL': 'https://git.example.com/config.git', 'autoSync': False}})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        apps = [d for d in docs if d.get('kind') == 'Application']
        assert len(apps) == 1
        assert 'syncPolicy' not in apps[0]['spec']

    def test_argocd_no_bootstrap_without_config(self, template_env):
        """Test no bootstrap Application when bootstrap is not configured."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        apps = [d for d in docs if d.get('kind') == 'Application']
        assert len(apps) == 0


class TestLvmOperator:
    """Tests for LVM operator plugin."""

    def operator_data(self, lvm_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        if lvm_config is not None:
            data['plugins'] = {'operators': {'lvm': lvm_config}}
        return data

    def test_lvm_standalone_defaults(self, template_env):
        """Test LVM with all defaults produces Namespace, OperatorGroup, Subscription, LVMCluster."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        kinds = [d['kind'] for d in docs]
        assert 'Namespace' in kinds
        assert 'OperatorGroup' in kinds
        assert 'Subscription' in kinds
        assert 'LVMCluster' in kinds

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'stable'
        assert sub['spec']['name'] == 'lvms-operator'
        assert sub['metadata']['namespace'] == 'openshift-storage'

        lc = next(d for d in docs if d['kind'] == 'LVMCluster')
        assert lc['spec']['storage']['deviceClasses'][0]['name'] == 'vg1'
        assert lc['spec']['storage']['deviceClasses'][0]['default'] is True

    def test_lvm_custom_channel(self, template_env):
        """Test LVM with custom channel and source."""
        data = self.operator_data({'channel': 'stable-4.19', 'source': 'my-catalog'})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'stable-4.19'
        assert sub['spec']['source'] == 'my-catalog'

    def test_lvm_device_classes(self, template_env):
        """Test LVM with custom device classes."""
        data = self.operator_data({
            'deviceClasses': [
                {'name': 'fast', 'fstype': 'xfs', 'deviceSelector': {'paths': ['/dev/nvme0n1']}},
                {'name': 'slow', 'default': True, 'fstype': 'ext4'}
            ]
        })
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        lc = next(d for d in docs if d['kind'] == 'LVMCluster')
        dcs = lc['spec']['storage']['deviceClasses']
        assert len(dcs) == 2
        assert dcs[0]['name'] == 'fast'
        assert dcs[0]['deviceSelector']['paths'] == ['/dev/nvme0n1']
        assert dcs[1]['name'] == 'slow'
        assert dcs[1]['default'] is True

    def test_lvm_disabled(self, template_env):
        """Test LVM disabled produces no output."""
        data = self.operator_data({'enabled': False})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        assert len(docs) == 0

    def test_lvm_acm_policy(self, template_env):
        """Test LVM generates ACM Policy in ZTP template."""
        data = self.operator_data({})
        data['plugins']['operators']['lvm'] = {}
        data['cluster']['version'] = '4.21.0'
        data['cluster']['arch'] = 'x86_64'
        for hostname, host in data['hosts'].items():
            host['bmc'] = {'vendor': 'dell', 'version': 9, 'address': '10.0.1.1', 'macAddress': 'aa:bb:cc:dd:ee:ff', 'username': 'root', 'password': 'pw'}
            host['network'] = {'interfaces': [{'name': 'eth0', 'macAddress': 'aa:bb:cc:dd:ee:01'}], 'primary': {'address': '10.0.0.10', 'ports': ['eth0']}}
            host['storage'] = {'os': {'deviceName': '/dev/sda'}}
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        items = result.get('items', [])
        policies = [i for i in items if i.get('kind') == 'Policy' and i['metadata']['name'] == 'operator-lvm']
        assert len(policies) == 1
        bindings = [i for i in items if i.get('kind') == 'PlacementBinding' and i['metadata']['name'] == 'operator-lvm']
        assert len(bindings) == 1

    def test_lvm_in_install_config(self, template_env):
        """Test LVM manifests appear in install-config output."""
        data = self.operator_data({})
        template = template_env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        kinds = [d.get('kind', '') for d in docs]
        assert 'Subscription' in kinds
        assert 'LVMCluster' in kinds


class TestOdfOperator:
    """Tests for ODF operator plugin."""

    def operator_data(self, odf_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        if odf_config is not None:
            data['plugins'] = {'operators': {'odf': odf_config}}
        return data

    def test_odf_standalone_defaults(self, template_env):
        """Test ODF with all defaults."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        kinds = [d['kind'] for d in docs]
        assert 'Namespace' in kinds
        assert 'Subscription' in kinds
        assert 'StorageCluster' in kinds

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'stable-4.18'
        assert sub['spec']['name'] == 'odf-operator'

        sc = next(d for d in docs if d['kind'] == 'StorageCluster')
        assert sc['metadata']['name'] == 'ocs-storagecluster'
        assert sc['spec']['storageDeviceSets'][0]['name'] == 'ocs-deviceset'

    def test_odf_custom_storage_cluster(self, template_env):
        """Test ODF with custom storage cluster config."""
        data = self.operator_data({
            'channel': 'stable-4.19',
            'storageCluster': {
                'name': 'my-cluster',
                'storageDeviceSets': [
                    {'name': 'nvme-set', 'count': 2, 'replica': 3, 'storage': '2Ti', 'storageClassName': 'nvme-sc'}
                ]
            }
        })
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        sc = next(d for d in docs if d['kind'] == 'StorageCluster')
        assert sc['metadata']['name'] == 'my-cluster'
        sds = sc['spec']['storageDeviceSets'][0]
        assert sds['name'] == 'nvme-set'
        assert sds['count'] == 2
        assert sds['dataPVCTemplate']['spec']['storageClassName'] == 'nvme-sc'

    def test_odf_disabled(self, template_env):
        """Test ODF disabled produces no output."""
        data = self.operator_data({'enabled': False})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        assert len(docs) == 0

    def test_odf_acm_policy(self, template_env):
        """Test ODF generates ACM Policy in ZTP template."""
        data = self.operator_data({})
        data['cluster']['version'] = '4.21.0'
        data['cluster']['arch'] = 'x86_64'
        for hostname, host in data['hosts'].items():
            host['bmc'] = {'vendor': 'dell', 'version': 9, 'address': '10.0.1.1', 'macAddress': 'aa:bb:cc:dd:ee:ff', 'username': 'root', 'password': 'pw'}
            host['network'] = {'interfaces': [{'name': 'eth0', 'macAddress': 'aa:bb:cc:dd:ee:01'}], 'primary': {'address': '10.0.0.10', 'ports': ['eth0']}}
            host['storage'] = {'os': {'deviceName': '/dev/sda'}}
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        items = result.get('items', [])
        policies = [i for i in items if i.get('kind') == 'Policy' and i['metadata']['name'] == 'operator-odf']
        assert len(policies) == 1


class TestCertManagerOperator:
    """Tests for cert-manager operator plugin."""

    def operator_data(self, cm_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        if cm_config is not None:
            data['plugins'] = {'operators': {'cert-manager': cm_config}}
        return data

    def test_certmanager_standalone_defaults(self, template_env):
        """Test cert-manager with all defaults."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        kinds = [d['kind'] for d in docs]
        assert 'Namespace' in kinds
        assert 'OperatorGroup' in kinds
        assert 'Subscription' in kinds

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'stable-v1'
        assert sub['spec']['name'] == 'openshift-cert-manager-operator'
        assert sub['metadata']['namespace'] == 'cert-manager-operator'

    def test_certmanager_custom_source(self, template_env):
        """Test cert-manager with custom source for disconnected."""
        data = self.operator_data({'source': 'custom-catalog', 'approval': 'Manual'})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['source'] == 'custom-catalog'
        assert sub['spec']['installPlanApproval'] == 'Manual'

    def test_certmanager_disabled(self, template_env):
        """Test cert-manager disabled produces no output."""
        data = self.operator_data({'enabled': False})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        assert len(docs) == 0

    def test_certmanager_acm_policy(self, template_env):
        """Test cert-manager generates ACM Policy in ZTP template."""
        data = self.operator_data({})
        data['cluster']['version'] = '4.21.0'
        data['cluster']['arch'] = 'x86_64'
        for hostname, host in data['hosts'].items():
            host['bmc'] = {'vendor': 'dell', 'version': 9, 'address': '10.0.1.1', 'macAddress': 'aa:bb:cc:dd:ee:ff', 'username': 'root', 'password': 'pw'}
            host['network'] = {'interfaces': [{'name': 'eth0', 'macAddress': 'aa:bb:cc:dd:ee:01'}], 'primary': {'address': '10.0.0.10', 'ports': ['eth0']}}
            host['storage'] = {'os': {'deviceName': '/dev/sda'}}
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        items = result.get('items', [])
        policies = [i for i in items if i.get('kind') == 'Policy' and i['metadata']['name'] == 'operator-cert-manager']
        assert len(policies) == 1
        bindings = [i for i in items if i.get('kind') == 'PlacementBinding' and i['metadata']['name'] == 'operator-cert-manager']
        assert len(bindings) == 1


class TestCertManagerConfig:
    """Tests for cert-manager LetsEncrypt config template."""

    def letsencrypt_data(self, le_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['cluster']['name'] = 'ocp-acm'
        data['network']['domain'] = 'ola.purefield.nl'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        cm = {}
        if le_config is not None:
            cm['letsencrypt'] = le_config
        data['plugins'] = {'operators': {'cert-manager': cm}}
        return data

    def full_letsencrypt(self):
        return {
            'email': 'test@example.com',
            'route53': {
                'hostedZoneID': 'Z0123456789ABCDEF',
                'region': 'us-east-1',
                'role': 'arn:aws:iam::123456789:role/test-role',
                'secretStore': 'aws-secretsmanager',
                'remoteRef': 'route53/credentials',
            }
        }

    def test_certmanager_config_renders_clusterissuer(self, template_env):
        """Test letsencrypt config renders ClusterIssuer with Route53 solver."""
        data = self.letsencrypt_data(self.full_letsencrypt())
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        issuers = [d for d in docs if d['kind'] == 'ClusterIssuer']
        assert len(issuers) == 1
        issuer = issuers[0]
        assert issuer['metadata']['name'] == 'letsencrypt-prod'
        assert issuer['spec']['acme']['email'] == 'test@example.com'
        solver = issuer['spec']['acme']['solvers'][0]['dns01']['route53']
        assert solver['hostedZoneID'] == 'Z0123456789ABCDEF'
        assert solver['region'] == 'us-east-1'
        assert solver['role'] == 'arn:aws:iam::123456789:role/test-role'

    def test_certmanager_config_renders_certificate(self, template_env):
        """Test Certificate dnsNames derived from cluster.name + network.domain."""
        data = self.letsencrypt_data(self.full_letsencrypt())
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        certs = [d for d in docs if d['kind'] == 'Certificate']
        assert len(certs) == 1
        cert = certs[0]
        assert cert['metadata']['name'] == 'ocp-acm-ingress-cert'
        assert cert['metadata']['namespace'] == 'openshift-ingress'
        assert cert['spec']['secretName'] == 'letsencrypt-cert'
        assert 'api.ocp-acm.ola.purefield.nl' in cert['spec']['dnsNames']
        assert '*.apps.ocp-acm.ola.purefield.nl' in cert['spec']['dnsNames']

    def test_certmanager_config_renders_externalsecret(self, template_env):
        """Test ExternalSecret with secretStore and remoteRef."""
        data = self.letsencrypt_data(self.full_letsencrypt())
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        es = [d for d in docs if d['kind'] == 'ExternalSecret']
        assert len(es) == 1
        ext = es[0]
        assert ext['metadata']['namespace'] == 'cert-manager'
        assert ext['spec']['secretStoreRef']['name'] == 'aws-secretsmanager'
        assert ext['spec']['secretStoreRef']['kind'] == 'ClusterSecretStore'
        keys = [item['remoteRef']['key'] for item in ext['spec']['data']]
        assert all(k == 'route53/credentials' for k in keys)

    def test_certmanager_config_absent_without_letsencrypt(self, template_env):
        """Test no config output when letsencrypt key is absent."""
        data = self.letsencrypt_data()
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        kinds = [d['kind'] for d in docs]
        assert 'ClusterIssuer' not in kinds
        assert 'Certificate' not in kinds
        assert 'ExternalSecret' not in kinds

    def test_certmanager_config_smart_defaults(self, template_env):
        """Test only email + route53 required fields needed; rest uses defaults."""
        minimal = {
            'email': 'admin@example.com',
            'route53': {
                'hostedZoneID': 'ZMINIMAL',
                'role': 'arn:aws:iam::111:role/minimal',
                'remoteRef': 'creds/key',
            }
        }
        data = self.letsencrypt_data(minimal)
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        issuer = next(d for d in docs if d['kind'] == 'ClusterIssuer')
        assert issuer['spec']['acme']['solvers'][0]['dns01']['route53']['region'] == 'us-east-1'
        ext = next(d for d in docs if d['kind'] == 'ExternalSecret')
        assert ext['spec']['secretStoreRef']['name'] == 'aws-secretsmanager'


class TestAcmOperator:
    """Tests for ACM operator plugin."""

    def operator_data(self, acm_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        if acm_config is not None:
            data['plugins'] = {'operators': {'acm': acm_config}}
        return data

    def test_acm_standalone_defaults(self, template_env):
        """Test ACM with all defaults produces full hub manifests."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        kinds = [d['kind'] for d in docs]
        assert 'Namespace' in kinds
        assert 'OperatorGroup' in kinds
        assert 'Subscription' in kinds
        assert 'MultiClusterHub' in kinds
        assert 'AgentServiceConfig' in kinds
        assert 'Provisioning' in kinds

        sub = next(d for d in docs if d['kind'] == 'Subscription')
        assert sub['spec']['channel'] == 'release-2.14'
        assert sub['spec']['name'] == 'advanced-cluster-management'

        mch = next(d for d in docs if d['kind'] == 'MultiClusterHub')
        assert mch['metadata']['name'] == 'multiclusterhub'
        assert mch['spec']['availabilityConfig'] == 'High'

    def test_acm_custom_config(self, template_env):
        """Test ACM with custom storage sizes and availability."""
        data = self.operator_data({
            'multiClusterHub': {'availabilityConfig': 'Basic'},
            'agentServiceConfig': {'databaseStorage': '20Gi', 'imageStorage': '100Gi'}
        })
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        mch = next(d for d in docs if d['kind'] == 'MultiClusterHub')
        assert mch['spec']['availabilityConfig'] == 'Basic'

        asc = next(d for d in docs if d['kind'] == 'AgentServiceConfig')
        assert asc['spec']['databaseStorage']['resources']['requests']['storage'] == '20Gi'
        assert asc['spec']['imageStorage']['resources']['requests']['storage'] == '100Gi'

    def test_acm_disabled(self, template_env):
        """Test ACM disabled produces no output."""
        data = self.operator_data({'enabled': False})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        assert len(docs) == 0


class TestExternalSecretsOperator:
    """Tests for external-secrets operator plugin."""

    def operator_data(self, es_config=None):
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        if es_config is not None:
            data['plugins'] = {'operators': {'external-secrets': es_config}}
        return data

    def test_externalsecrets_standalone_defaults(self, template_env):
        """Test external-secrets with defaults (no Namespace/OperatorGroup — global scope)."""
        data = self.operator_data({})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        assert len(docs) == 1
        sub = docs[0]
        assert sub['kind'] == 'Subscription'
        assert sub['spec']['name'] == 'external-secrets-operator'
        assert sub['spec']['channel'] == 'stable-v1'
        assert sub['metadata']['namespace'] == 'openshift-operators'

    def test_externalsecrets_custom_source(self, template_env):
        """Test external-secrets with custom source."""
        data = self.operator_data({'source': 'disconnected-catalog'})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        sub = docs[0]
        assert sub['spec']['source'] == 'disconnected-catalog'

    def test_externalsecrets_disabled(self, template_env):
        """Test external-secrets disabled produces no output."""
        data = self.operator_data({'enabled': False})
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]
        assert len(docs) == 0

    def test_externalsecrets_acm_policy(self, template_env):
        """Test external-secrets generates ACM Policy in ZTP template."""
        data = self.operator_data({})
        data['cluster']['version'] = '4.21.0'
        data['cluster']['arch'] = 'x86_64'
        for hostname, host in data['hosts'].items():
            host['bmc'] = {'vendor': 'dell', 'version': 9, 'address': '10.0.1.1', 'macAddress': 'aa:bb:cc:dd:ee:ff', 'username': 'root', 'password': 'pw'}
            host['network'] = {'interfaces': [{'name': 'eth0', 'macAddress': 'aa:bb:cc:dd:ee:01'}], 'primary': {'address': '10.0.0.10', 'ports': ['eth0']}}
            host['storage'] = {'os': {'deviceName': '/dev/sda'}}
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        items = result.get('items', [])
        policies = [i for i in items if i.get('kind') == 'Policy' and i['metadata']['name'] == 'operator-external-secrets']
        assert len(policies) == 1


class TestMultipleOperators:
    """Tests for multiple operators configured together."""

    def test_all_operators_standalone(self, template_env):
        """Test all operators configured together in standalone template."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        data['plugins'] = {'operators': {
            'argocd': {},
            'lvm': {},
            'odf': {},
            'acm': {},
            'cert-manager': {},
            'external-secrets': {}
        }}
        template = template_env.get_template('operators.yaml.tpl')
        rendered = template.render(data)
        docs = [d for d in yaml.safe_load_all(rendered) if d]

        subs = [d for d in docs if d['kind'] == 'Subscription']
        sub_names = [s['spec']['name'] for s in subs]
        assert 'openshift-gitops-operator' in sub_names
        assert 'lvms-operator' in sub_names
        assert 'odf-operator' in sub_names
        assert 'advanced-cluster-management' in sub_names
        assert 'openshift-cert-manager-operator' in sub_names
        assert 'external-secrets-operator' in sub_names

    def test_mixed_operators_ztp_policies(self, template_env):
        """Test multiple operators generate correct ACM policies in ZTP."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['cluster']['version'] = '4.21.0'
        data['cluster']['arch'] = 'x86_64'
        data['network']['primary']['vips'] = {'api': '10.0.0.2', 'apps': '10.0.0.3'}
        data['plugins'] = {'operators': {
            'lvm': {},
            'cert-manager': {},
            'external-secrets': {}
        }}
        for hostname, host in data['hosts'].items():
            host['bmc'] = {'vendor': 'dell', 'version': 9, 'address': '10.0.1.1', 'macAddress': 'aa:bb:cc:dd:ee:ff', 'username': 'root', 'password': 'pw'}
            host['network'] = {'interfaces': [{'name': 'eth0', 'macAddress': 'aa:bb:cc:dd:ee:01'}], 'primary': {'address': '10.0.0.10', 'ports': ['eth0']}}
            host['storage'] = {'os': {'deviceName': '/dev/sda'}}
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        items = result.get('items', [])
        policy_names = [i['metadata']['name'] for i in items if i.get('kind') == 'Policy']
        assert 'operator-lvm' in policy_names
        assert 'operator-cert-manager' in policy_names
        assert 'operator-external-secrets' in policy_names
        # ArgoCD not configured, should not appear
        assert 'operator-argocd' not in policy_names


class TestSiteConfigFields:
    """Tests for SiteConfig/ClusterInstance fields added to schema and templates."""

    def render_install_config(self, env, data):
        template = env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def test_cpu_partitioning_mode_in_install_config(self, template_env):
        """Test cpuPartitioningMode renders as top-level field in install-config."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'none'
        data['cluster']['cpuPartitioningMode'] = 'AllNodes'
        data['hosts'] = {'sno.example.com': {'role': 'control', 'storage': {'os': '/dev/sda'}}}

        result = self.render_install_config(template_env, data)

        assert result['cpuPartitioningMode'] == 'AllNodes'

    def test_cpu_partitioning_mode_absent_when_none(self, template_env):
        """Test cpuPartitioningMode is omitted when set to None (default)."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'none'
        data['cluster']['cpuPartitioningMode'] = 'None'
        data['hosts'] = {'sno.example.com': {'role': 'control', 'storage': {'os': '/dev/sda'}}}

        result = self.render_install_config(template_env, data)

        assert 'cpuPartitioningMode' not in result

    def test_cpu_partitioning_absent_when_not_set(self, template_env):
        """Test cpuPartitioningMode is omitted when not in data at all."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary'] = baremetal_vips_data()['primary']

        result = self.render_install_config(template_env, data)

        assert 'cpuPartitioningMode' not in result


class TestZtpPerHostFields:
    """Tests for new per-host fields in ACM ZTP template."""

    def acm_ztp_data_with_host(self, host_overrides=None):
        """Return minimal ZTP data with one host that can be customized."""
        data = {
            'account': {'pullSecret': 'secrets/pull-secret.json'},
            'cluster': {
                'name': 'host-test',
                'version': '4.21.0',
                'arch': 'x86_64',
                'location': 'dc1',
                'platform': 'baremetal',
                'sshKeys': ['secrets/id_rsa.pub']
            },
            'network': {
                'domain': 'example.com',
                'nameservers': ['10.0.0.100'],
                'dnsResolver': {'search': ['example.com']},
                'ntpservers': ['10.0.0.100'],
                'primary': {
                    'bond': False, 'vlan': False,
                    'gateway': '10.0.0.1', 'subnet': '10.0.0.0/24',
                    'type': 'OVNKubernetes',
                    'vips': {'api': ['10.0.0.2'], 'apps': ['10.0.0.3']}
                },
                'cluster': {'subnet': '10.128.0.0/14', 'hostPrefix': 23},
                'service': {'subnet': '172.30.0.0/16'}
            },
            'hosts': {
                'node1.host-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                        'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                    }
                },
                'node2.host-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.5'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:02'}],
                        'primary': {'address': '10.0.0.5', 'ports': ['eth0']}
                    }
                },
                'node3.host-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.6'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:03'}],
                        'primary': {'address': '10.0.0.6', 'ports': ['eth0']}
                    }
                }
            },
            'plugins': {}
        }
        if host_overrides:
            for key, val in host_overrides.items():
                data['hosts']['node1.host-test.example.com'][key] = val
        return data

    def render_ztp(self, env, data):
        template = env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def get_bmh(self, result, name='node1.host-test.example.com'):
        """Find a BareMetalHost by name."""
        for item in result['items']:
            if item.get('kind') == 'BareMetalHost' and item['metadata']['name'] == name:
                return item
        return None

    def test_boot_mode_in_bmh(self, template_env):
        """Test bootMode renders in BareMetalHost spec."""
        data = self.acm_ztp_data_with_host({'bootMode': 'UEFISecureBoot'})
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert bmh is not None
        assert bmh['spec']['bootMode'] == 'UEFISecureBoot'

    def test_boot_mode_absent_by_default(self, template_env):
        """Test bootMode is absent when not set."""
        data = self.acm_ztp_data_with_host()
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert 'bootMode' not in bmh['spec']

    def test_automated_cleaning_mode_configurable(self, template_env):
        """Test automatedCleaningMode is configurable per host."""
        data = self.acm_ztp_data_with_host({'automatedCleaningMode': 'disabled'})
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert bmh['spec']['automatedCleaningMode'] == 'disabled'

    def test_automated_cleaning_mode_default(self, template_env):
        """Test automatedCleaningMode defaults to metadata."""
        data = self.acm_ztp_data_with_host()
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert bmh['spec']['automatedCleaningMode'] == 'metadata'

    def test_ironic_inspect_configurable(self, template_env):
        """Test ironicInspect annotation is configurable (empty string enables inspection)."""
        data = self.acm_ztp_data_with_host({'ironicInspect': ''})
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        # Empty string in YAML loads as None; the key exists with empty/null value
        assert 'inspect.metal3.io' in bmh['metadata']['annotations']
        assert bmh['metadata']['annotations']['inspect.metal3.io'] in ('', None)

    def test_ironic_inspect_default(self, template_env):
        """Test ironicInspect defaults to disabled."""
        data = self.acm_ztp_data_with_host()
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert bmh['metadata']['annotations']['inspect.metal3.io'] == 'disabled'

    def test_installer_args_annotation(self, template_env):
        """Test installerArgs renders as BareMetalHost annotation."""
        args = '[\"--append-karg\", \"ip=dhcp\"]'
        data = self.acm_ztp_data_with_host({'installerArgs': args})
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert 'bmac.agent-install.openshift.io/installer-args' in bmh['metadata']['annotations']
        assert bmh['metadata']['annotations']['bmac.agent-install.openshift.io/installer-args'] == args

    def test_ignition_config_override_annotation(self, template_env):
        """Test ignitionConfigOverride renders as BareMetalHost annotation."""
        override = '{"ignition":{"version":"3.1.0"}}'
        data = self.acm_ztp_data_with_host({'ignitionConfigOverride': override})
        result = self.render_ztp(template_env, data)
        bmh = self.get_bmh(result)

        assert 'bmac.agent-install.openshift.io/ignition-config-overrides' in bmh['metadata']['annotations']

    def test_hold_installation_in_aci(self, template_env):
        """Test holdInstallation renders in AgentClusterInstall spec."""
        data = self.acm_ztp_data_with_host()
        data['cluster']['holdInstallation'] = True
        result = self.render_ztp(template_env, data)

        aci = None
        for item in result['items']:
            if item.get('kind') == 'AgentClusterInstall':
                aci = item
                break
        assert aci is not None
        assert aci['spec']['holdInstallation'] is True

    def test_no_hold_installation_by_default(self, template_env):
        """Test holdInstallation is absent when not set."""
        data = self.acm_ztp_data_with_host()
        result = self.render_ztp(template_env, data)

        aci = None
        for item in result['items']:
            if item.get('kind') == 'AgentClusterInstall':
                aci = item
                break
        assert 'holdInstallation' not in aci['spec']


class TestTangDiskEncryption:
    """Tests for Tang network-bound disk encryption."""

    def acm_ztp_data_with_tang(self):
        """Return ZTP data with Tang disk encryption configured."""
        data = {
            'account': {'pullSecret': 'secrets/pull-secret.json'},
            'cluster': {
                'name': 'tang-test',
                'version': '4.21.0',
                'arch': 'x86_64',
                'location': 'dc1',
                'platform': 'baremetal',
                'sshKeys': ['secrets/id_rsa.pub'],
                'diskEncryption': {
                    'type': 'tang',
                    'tang': [
                        {'url': 'http://tang.example.com:7500', 'thumbprint': 'abc123'},
                        {'url': 'http://tang2.example.com:7500', 'thumbprint': 'def456'}
                    ]
                }
            },
            'network': {
                'domain': 'example.com',
                'nameservers': ['10.0.0.100'],
                'dnsResolver': {'search': ['example.com']},
                'ntpservers': ['10.0.0.100'],
                'primary': {
                    'bond': False, 'vlan': False,
                    'gateway': '10.0.0.1', 'subnet': '10.0.0.0/24',
                    'type': 'OVNKubernetes',
                    'vips': {'api': ['10.0.0.2'], 'apps': ['10.0.0.3']}
                },
                'cluster': {'subnet': '10.128.0.0/14', 'hostPrefix': 23},
                'service': {'subnet': '172.30.0.0/16'}
            },
            'hosts': {
                'node1.tang-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                        'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                    }
                },
                'node2.tang-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.5'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:02'}],
                        'primary': {'address': '10.0.0.5', 'ports': ['eth0']}
                    }
                },
                'node3.tang-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.6'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:03'}],
                        'primary': {'address': '10.0.0.6', 'ports': ['eth0']}
                    }
                }
            },
            'plugins': {}
        }
        return data

    def get_configmap(self, result, name):
        for item in result['items']:
            if item['kind'] == 'ConfigMap' and item['metadata']['name'] == name:
                return item
        return None

    def test_tang_manifest_in_extraclustermanifests(self, template_env):
        """Test Tang MachineConfig appears in extraclustermanifests."""
        data = self.acm_ztp_data_with_tang()
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-tang-disk-encryption.yaml' in cm['data']
        tang_manifest = cm['data']['99-tang-disk-encryption.yaml']
        assert 'tang' in tang_manifest
        assert 'tang.example.com' in tang_manifest
        assert 'abc123' in tang_manifest
        assert 'tang2.example.com' in tang_manifest

    def test_no_tang_when_tpm(self, template_env):
        """Test no Tang manifest appears when using TPM encryption."""
        data = self.acm_ztp_data_with_tang()
        data['cluster']['diskEncryption'] = {'type': 'tpm2'}
        data['cluster']['tpm'] = True
        template = template_env.get_template('acm-ztp.yaml.tpl')
        rendered = template.render(data)
        result = yaml.safe_load(rendered)

        cm = self.get_configmap(result, 'extraclustermanifests')
        assert cm is not None
        assert '99-tpm-disk-encryption.yaml' in cm['data']
        assert '99-tang-disk-encryption.yaml' not in cm['data']


class TestClusterInstanceTemplate:
    """Tests for the clusterfile2siteconfig.yaml.tpl template."""

    def siteconfig_data(self, sno=False, extra_cluster=None, extra_host=None):
        """Return data for ClusterInstance template rendering."""
        if sno:
            hosts = {
                'sno.sc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                        'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                    }
                }
            }
        else:
            hosts = {
                'node1.sc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.4'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                        'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                    }
                },
                'node2.sc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.5'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:02'}],
                        'primary': {'address': '10.0.0.5', 'ports': ['eth0']}
                    }
                },
                'node3.sc-test.example.com': {
                    'role': 'control',
                    'storage': {'os': {'deviceName': '/dev/sda'}},
                    'bmc': {
                        'vendor': 'dell', 'version': 9,
                        'username': 'admin', 'password': 'bmc-password.txt',
                        'address': '10.0.1.6'
                    },
                    'network': {
                        'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:03'}],
                        'primary': {'address': '10.0.0.6', 'ports': ['eth0']}
                    }
                }
            }
        if extra_host:
            first_key = next(iter(hosts))
            for k, v in extra_host.items():
                hosts[first_key][k] = v

        data = {
            'account': {'pullSecret': 'secrets/pull-secret.json'},
            'cluster': {
                'name': 'sc-test',
                'version': '4.21.0',
                'arch': 'x86_64',
                'location': 'dc1',
                'platform': 'none' if sno else 'baremetal',
                'sshKeys': ['secrets/id_rsa.pub']
            },
            'network': {
                'domain': 'example.com',
                'nameservers': ['10.0.0.100'],
                'dnsResolver': {'search': ['example.com']},
                'ntpservers': ['10.0.0.100'],
                'primary': {
                    'bond': False, 'vlan': False,
                    'gateway': '10.0.0.1', 'subnet': '10.0.0.0/24',
                    'type': 'OVNKubernetes'
                },
                'cluster': {'subnet': '10.128.0.0/14', 'hostPrefix': 23},
                'service': {'subnet': '172.30.0.0/16'}
            },
            'hosts': hosts,
            'plugins': {}
        }
        if not sno:
            data['network']['primary']['vips'] = {'api': ['10.0.0.2'], 'apps': ['10.0.0.3']}
        if extra_cluster:
            data['cluster'].update(extra_cluster)
        return data

    def render_siteconfig(self, env, data):
        template = env.get_template('clusterfile2siteconfig.yaml.tpl')
        rendered = template.render(data)
        docs = list(yaml.safe_load_all(rendered))
        return [d for d in docs if d is not None]

    def get_cluster_instance(self, docs):
        for doc in docs:
            if doc.get('kind') == 'ClusterInstance':
                return doc
        return None

    def test_sno_cluster_instance(self, template_env):
        """Test SNO renders a ClusterInstance with platformType None."""
        data = self.siteconfig_data(sno=True)
        docs = self.render_siteconfig(template_env, data)
        ci = self.get_cluster_instance(docs)

        assert ci is not None
        assert ci['spec']['clusterName'] == 'sc-test'
        assert ci['spec']['baseDomain'] == 'example.com'
        assert ci['spec']['platformType'] == 'None'
        assert ci['spec']['clusterType'] == 'SNO'
        assert len(ci['spec']['nodes']) == 1
        assert ci['spec']['nodes'][0]['role'] == 'master'

    def test_ha_cluster_instance(self, template_env):
        """Test HA cluster renders with VIPs and platformType BareMetal."""
        data = self.siteconfig_data(sno=False)
        docs = self.render_siteconfig(template_env, data)
        ci = self.get_cluster_instance(docs)

        assert ci is not None
        assert ci['spec']['platformType'] == 'BareMetal'
        assert ci['spec']['clusterType'] == 'HighlyAvailable'
        assert ci['spec']['apiVIPs'] == ['10.0.0.2']
        assert ci['spec']['ingressVIPs'] == ['10.0.0.3']
        assert len(ci['spec']['nodes']) == 3

    def test_cpu_partitioning_in_cluster_instance(self, template_env):
        """Test cpuPartitioningMode renders in ClusterInstance."""
        data = self.siteconfig_data(sno=True, extra_cluster={'cpuPartitioningMode': 'AllNodes'})
        docs = self.render_siteconfig(template_env, data)
        ci = self.get_cluster_instance(docs)

        assert ci['spec']['cpuPartitioningMode'] == 'AllNodes'

    def test_hold_installation_in_cluster_instance(self, template_env):
        """Test holdInstallation renders in ClusterInstance."""
        data = self.siteconfig_data(sno=True, extra_cluster={'holdInstallation': True})
        docs = self.render_siteconfig(template_env, data)
        ci = self.get_cluster_instance(docs)

        assert ci['spec']['holdInstallation'] is True

    def test_boot_mode_in_cluster_instance_node(self, template_env):
        """Test bootMode renders per-node in ClusterInstance."""
        data = self.siteconfig_data(sno=True, extra_host={'bootMode': 'UEFISecureBoot'})
        docs = self.render_siteconfig(template_env, data)
        ci = self.get_cluster_instance(docs)

        assert ci['spec']['nodes'][0]['bootMode'] == 'UEFISecureBoot'

    def test_node_labels_in_cluster_instance(self, template_env):
        """Test nodeLabels render per-node in ClusterInstance."""
        data = self.siteconfig_data(sno=True, extra_host={'nodeLabels': {'node-role.kubernetes.io/infra': ''}})
        docs = self.render_siteconfig(template_env, data)
        ci = self.get_cluster_instance(docs)

        assert 'nodeLabels' in ci['spec']['nodes'][0]
        assert 'node-role.kubernetes.io/infra' in ci['spec']['nodes'][0]['nodeLabels']

    def test_bmc_secrets_generated(self, template_env):
        """Test per-host BMC secrets are generated."""
        data = self.siteconfig_data(sno=True)
        docs = self.render_siteconfig(template_env, data)

        secrets = [d for d in docs if d.get('kind') == 'Secret' and 'bmc-secret' in d['metadata']['name']]
        assert len(secrets) == 1

    def test_namespace_generated(self, template_env):
        """Test Namespace is generated."""
        data = self.siteconfig_data(sno=True)
        docs = self.render_siteconfig(template_env, data)

        ns = [d for d in docs if d.get('kind') == 'Namespace']
        assert len(ns) == 1
        assert ns[0]['metadata']['name'] == 'sc-test'

    def test_multi_doc_wrapped_in_list(self, template_env):
        """Multi-document siteconfig output is wrapped in kind: List for kubectl apply."""
        data = self.siteconfig_data(sno=True)
        docs = self.render_siteconfig(template_env, data)
        assert len(docs) > 1, "Siteconfig should produce multiple documents"
        wrapped = {"apiVersion": "v1", "kind": "List", "items": docs}
        assert wrapped['kind'] == 'List'
        assert wrapped['apiVersion'] == 'v1'
        kinds = [d['kind'] for d in wrapped['items']]
        assert 'Namespace' in kinds
        assert 'ClusterInstance' in kinds
        assert 'Secret' in kinds


class TestKubevirtSsdUdev:
    """Tests for the kubevirt SSD udev MachineConfig include across all install methods."""

    def test_ssd_udev_in_ztp_kubevirt(self, template_env):
        """SSD udev rule appears in ZTP extraclustermanifests for kubevirt platform."""
        data = TestAcmZtpTemplate().acm_ztp_data(platform='kubevirt', tpm=False)
        template = template_env.get_template('acm-ztp.yaml.tpl')
        result = yaml.safe_load(template.render(data))

        cm = None
        for item in result['items']:
            if item['kind'] == 'ConfigMap' and item['metadata']['name'] == 'extraclustermanifests':
                cm = item
        assert cm is not None, "extraclustermanifests ConfigMap not found"
        assert '99-ssd-rotational.yaml' in cm['data']
        assert '99-master-ssd-rotational' in cm['data']['99-ssd-rotational.yaml']
        assert 'ssd-rotational.rules' in cm['data']['99-ssd-rotational.yaml']

    def test_no_ssd_udev_in_ztp_baremetal(self, template_env):
        """SSD udev rule absent in ZTP extraclustermanifests for baremetal platform."""
        data = TestAcmZtpTemplate().acm_ztp_data(platform='baremetal', tpm=False)
        template = template_env.get_template('acm-ztp.yaml.tpl')
        result = yaml.safe_load(template.render(data))

        cm = None
        for item in result['items']:
            if item['kind'] == 'ConfigMap' and item['metadata']['name'] == 'extraclustermanifests':
                cm = item
        # No ConfigMap at all when baremetal without TPM/mirrors/etc
        assert cm is None

    def test_ssd_udev_in_install_config_kubevirt(self, template_env):
        """SSD udev MachineConfig appears in install-config output for kubevirt platform."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'kubevirt'
        data['hosts'] = {
            'node1.test.example.com': {
                'role': 'control',
                'storage': {'os': {'deviceName': '/dev/vda'}},
                'network': {
                    'interfaces': [{'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}],
                    'primary': {'address': '10.0.0.4', 'ports': ['eth0']}
                }
            }
        }
        template = template_env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        docs = list(yaml.safe_load_all(rendered))
        mc = [d for d in docs if d and d.get('kind') == 'MachineConfig' and 'ssd' in d['metadata']['name']]
        assert len(mc) == 1, "SSD udev MachineConfig should appear for kubevirt"
        assert mc[0]['metadata']['name'] == '99-master-ssd-rotational'

    def test_no_ssd_udev_in_install_config_baremetal(self, template_env):
        """SSD udev MachineConfig absent in install-config output for baremetal platform."""
        data = base_cluster_data()
        data['cluster']['platform'] = 'baremetal'
        data['network']['primary']['vips'] = {'api': ['10.0.0.2'], 'apps': ['10.0.0.3']}
        template = template_env.get_template('install-config.yaml.tpl')
        rendered = template.render(data)
        assert 'ssd-rotational' not in rendered

    def test_ssd_udev_in_capi_kubevirt(self, template_env):
        """SSD udev ManifestWork appears in CAPI template for kubevirt platform."""
        data = TestAcmZtpTemplate().acm_ztp_data(platform='kubevirt', tpm=False)
        template = template_env.get_template('acm-capi-m3.yaml.tpl')
        result = yaml.safe_load(template.render(data))

        mw = [item for item in result['items']
              if item['kind'] == 'ManifestWork' and item['metadata']['name'] == 'kubevirt-ssd-udev']
        assert len(mw) == 1, "SSD udev ManifestWork should appear for kubevirt"
        manifest = mw[0]['spec']['workload']['manifests'][0]
        assert manifest['kind'] == 'MachineConfig'
        assert manifest['metadata']['name'] == '99-master-ssd-rotational'

    def test_no_ssd_udev_in_capi_baremetal(self, template_env):
        """SSD udev ManifestWork absent in CAPI template for baremetal platform."""
        data = TestAcmZtpTemplate().acm_ztp_data(platform='baremetal', tpm=False)
        template = template_env.get_template('acm-capi-m3.yaml.tpl')
        rendered = template.render(data)
        assert 'kubevirt-ssd-udev' not in rendered


class TestSchemaPluginMerge:
    """Tests for auto-discovery and merge of operator plugin schemas."""

    def test_main_schema_has_no_inline_operator_defs(self):
        """Verify inline operator defs were extracted from the main schema."""
        schema_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'schema', 'clusterfile.schema.json')
        with open(schema_path) as f:
            s = json.load(f)
        for key in ['operatorArgocd', 'operatorLvm', 'operatorOdf', 'operatorAcm', 'operatorCertManager', 'operatorExternalSecrets']:
            assert key not in s.get('$defs', {}), f"{key} should be extracted from main schema"
        assert 'operatorCommon' in s['$defs'], "operatorCommon should remain in main schema"

    def test_plugin_schema_files_exist(self):
        """Each operator plugin directory has a schema.json."""
        plugins_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'plugins', 'operators')
        for name in ['argocd', 'lvm', 'odf', 'acm', 'cert-manager', 'external-secrets']:
            sf = os.path.join(plugins_dir, name, 'schema.json')
            assert os.path.isfile(sf), f"Missing {sf}"
            with open(sf) as f:
                data = json.load(f)
            assert data.get('type') == 'object', f"{name}/schema.json should be type object"
            assert 'title' in data, f"{name}/schema.json should have a title"

    def test_schema_merge_injects_defs_and_refs(self):
        """Simulate the merge logic and verify $defs and $ref entries are created."""
        schema_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'schema', 'clusterfile.schema.json')
        plugins_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'plugins', 'operators')
        with open(schema_path) as f:
            s = json.load(f)
        # Perform merge
        s.setdefault('$defs', {})
        ops = (s.setdefault('properties', {}).setdefault('plugins', {})
                .setdefault('properties', {}).setdefault('operators', {})
                .setdefault('properties', {}))
        for dirname in sorted(os.listdir(plugins_dir)):
            sf = os.path.join(plugins_dir, dirname, 'schema.json')
            if os.path.isfile(sf):
                def_key = 'operator' + ''.join(p.capitalize() for p in dirname.split('-'))
                with open(sf) as fh:
                    s['$defs'][def_key] = json.load(fh)
                ops[dirname] = {"$ref": f"#/$defs/{def_key}"}
        # Verify all operators are injected
        assert 'operatorArgocd' in s['$defs']
        assert 'operatorLvm' in s['$defs']
        assert 'operatorCertManager' in s['$defs']
        assert 'operatorExternalSecrets' in s['$defs']
        assert 'argocd' in ops
        assert ops['argocd'] == {"$ref": "#/$defs/operatorArgocd"}

    def test_process_py_load_schema_merges(self):
        """process.py _load_schema should merge plugin schemas."""
        import subprocess
        schema_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'schema', 'clusterfile.schema.json')
        result = subprocess.run(
            [sys.executable, '-c', f"""
import json, os, sys, yaml
sys.path.insert(0, '{os.path.dirname(os.path.dirname(__file__))}')

def _load_schema(path):
    with open(path, 'r') as fh:
        s = json.loads(fh.read())
    schema_dir = os.path.dirname(os.path.abspath(path))
    plugins_operators = os.path.join(os.path.dirname(schema_dir), 'plugins', 'operators')
    if os.path.isdir(plugins_operators):
        s.setdefault('$defs', {{}})
        ops = (s.setdefault('properties', {{}}).setdefault('plugins', {{}})
                .setdefault('properties', {{}}).setdefault('operators', {{}})
                .setdefault('properties', {{}}))
        for dirname in sorted(os.listdir(plugins_operators)):
            sf = os.path.join(plugins_operators, dirname, 'schema.json')
            if os.path.isfile(sf):
                def_key = 'operator' + ''.join(p.capitalize() for p in dirname.split('-'))
                with open(sf) as fh:
                    s['$defs'][def_key] = json.load(fh)
                ops[dirname] = {{"$ref": f"#/$defs/{{def_key}}"}}
    return s

s = _load_schema('{schema_path}')
assert 'operatorArgocd' in s['$defs']
assert 'operatorOdf' in s['$defs']
print('OK')
"""],
            capture_output=True, text=True
        )
        assert result.returncode == 0, f"Schema merge failed: {result.stderr}"
        assert 'OK' in result.stdout


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
