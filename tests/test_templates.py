#!/usr/bin/env python3
"""
Comprehensive test suite for Jinja2 template rendering.
Tests all platforms, configuration options, and includes.
"""
import pytest
import yaml
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

    env = Environment(loader=FileSystemLoader([template_dir, includes_dir]))

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

    def kubevirt_cluster_data(self, tpm=False):
        """Return minimal data for kubevirt-cluster template rendering."""
        return {
            'cluster': {
                'name': 'kv-test',
                'machine': {
                    'control': {
                        'cpus': 8, 'sockets': 1, 'memory': 32,
                        'storage': {'os': 120}
                    },
                    'worker': {
                        'cpus': 8, 'sockets': 1, 'memory': 32,
                        'storage': {'os': 120}
                    }
                }
            },
            'network': {
                'primary': {'vlan': False}
            },
            'plugins': {
                'kubevirt': {
                    'storageClass': {'default': 'lvms-vg1'},
                    'network': {'type': 'cudn', 'vlan': '1410'},
                    'tpm': tpm
                }
            },
            'hosts': {
                'node1.kv-test.example.com': {
                    'role': 'control',
                    'network': {
                        'interfaces': [
                            {'name': 'eth0', 'macAddress': '00:1A:2B:3C:4D:01'}
                        ]
                    }
                }
            }
        }

    def render_template(self, env, data):
        """Render kubevirt-cluster template and parse YAML."""
        template = env.get_template('kubevirt-cluster.yaml.tpl')
        rendered = template.render(data)
        return yaml.safe_load(rendered)

    def get_vm(self, result):
        """Extract the first VirtualMachine from the rendered List."""
        for item in result['items']:
            if item['kind'] == 'VirtualMachine':
                return item
        return None

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
        del data['plugins']['kubevirt']['tpm']
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


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
