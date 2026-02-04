{% set osp = plugins.openstack %}
      openstack:
        type: {{ osp.computeFlavor | default("m1.xlarge", true) }}
