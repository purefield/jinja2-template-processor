{%- set odf = plugins.operators.odf -%}
{%- set odfEnabled = odf.enabled | default(true) -%}
{%- set odfChannel = odf.channel | default("stable-" + cluster.version.split(".")[:2] | join(".")) -%}
{%- set sc = odf.storageCluster | default({}) -%}
{%- if odfEnabled %}
---
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-storage
  labels:
    openshift.io/cluster-monitoring: "true"
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
    - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-operator
  namespace: openshift-storage
spec:
  channel: {{ odfChannel }}
  installPlanApproval: {{ odf.approval | default("Automatic") }}
  name: odf-operator
  source: {{ odf.source | default("redhat-operators") }}
  sourceNamespace: openshift-marketplace
---
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: {{ sc.name | default("ocs-storagecluster") }}
  namespace: openshift-storage
spec:
  monDataDirHostPath: {{ sc.monDataDirHostPath | default("/var/lib/rook") }}
  storageDeviceSets:{% if sc.storageDeviceSets is defined %}{% for sds in sc.storageDeviceSets %}
    - name: {{ sds.name | default("ocs-deviceset") }}
      count: {{ sds.count | default(1) }}
      replica: {{ sds.replica | default(3) }}
      portable: true
      dataPVCTemplate:
        spec:
          accessModes:
            - ReadWriteOnce{% if sds.storageClassName is defined and sds.storageClassName %}
          storageClassName: {{ sds.storageClassName }}{% endif %}
          resources:
            requests:
              storage: {{ sds.storage | default("1Ti") }}
          volumeMode: Block{% endfor %}{% else %}
    - name: ocs-deviceset
      count: 1
      replica: 3
      portable: true
      dataPVCTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Ti
          volumeMode: Block{% endif %}{% if odf.consolePlugin | default(true) %}
---
apiVersion: console.openshift.io/v1
kind: ConsolePlugin
metadata:
  name: odf-console
spec:
  displayName: ODF Console
  backend:
    type: Service
    service:
      name: odf-console-service
      namespace: openshift-storage
      port: 9001{% endif %}
{%- endif -%}
