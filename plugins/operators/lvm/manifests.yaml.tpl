{%- set lvm = plugins.operators.lvm -%}
{%- set lvmEnabled = lvm.enabled | default(true) -%}
{%- if lvmEnabled %}
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-storage
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
    - openshift-storage
  upgradeStrategy: Default
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: lvms-operator
  namespace: openshift-storage
  labels:
    operators.coreos.com/lvms-operator.openshift-storage: ""
spec:
  channel: {{ lvm.channel | default("stable") }}
  installPlanApproval: {{ lvm.approval | default("Automatic") }}
  name: lvms-operator
  source: {{ lvm.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace
---
apiVersion: lvm.topolvm.io/v1alpha1
kind: LVMCluster
metadata:
  name: lvmcluster
  namespace: openshift-storage
spec:
  storage:
    deviceClasses:{% if lvm.deviceClasses is defined %}{% for dc in lvm.deviceClasses %}
      - name: {{ dc.name | default("vg1") }}{% if dc.vgName is defined %}
        vgName: {{ dc.vgName }}{% endif %}{% if dc.default is defined %}
        default: {{ dc.default | lower }}{% elif loop.first %}
        default: true{% endif %}
        fstype: {{ dc.fstype | default("xfs") }}{% if dc.thinPoolConfig is defined %}
        thinPoolConfig:
          name: {{ dc.thinPoolConfig.name | default("thin-pool-1") }}
          sizePercent: {{ dc.thinPoolConfig.sizePercent | default(90) }}
          overprovisionRatio: {{ dc.thinPoolConfig.overprovisionRatio | default(10) }}{% endif %}{% if dc.deviceSelector is defined %}
        deviceSelector:{% if dc.deviceSelector.paths is defined %}
          paths:{% for p in dc.deviceSelector.paths %}
            - {{ p }}{% endfor %}{% endif %}{% if dc.deviceSelector.optionalPaths is defined %}
          optionalPaths:{% for p in dc.deviceSelector.optionalPaths %}
            - {{ p }}{% endfor %}{% endif %}{% if dc.deviceSelector.forceWipeDevicesAndDestroyAllData | default(false) %}
          forceWipeDevicesAndDestroyAllData: true{% endif %}{% endif %}{% endfor %}{% else %}
      - name: vg1
        default: true
        fstype: xfs
        thinPoolConfig:
          name: thin-pool-1
          sizePercent: 90
          overprovisionRatio: 10{% endif %}
{%- endif -%}
