{% set osp = plugins.openstack %}
    openstack:
      type: {{ osp.controlPlaneFlavor | default(osp.computeFlavor, true) | default("m1.xlarge", true) }}
