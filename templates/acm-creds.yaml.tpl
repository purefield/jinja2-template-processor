apiVersion: v1
kind: List
metadata:
  resourceVersion: ""
items:
- kind: Namespace
  apiVersion: v1
  metadata:
    name: hosted-inventory-creds
- kind: Secret
  apiVersion: v1
  type: Opaque
  metadata:
    name: {{ cluster.name }}-creds
    namespace: hosted-inventory-creds
    labels:
      cluster.open-cluster-management.io/credentials: ""
      cluster.open-cluster-management.io/type: hostinventory
  stringData:
    baseDomain: {{ network.domain }}
    pullSecret: '{{load_file(account.pullSecret)}}'
    ssh-publickey: '{{load_file(cluster.sshKeys|first)}}'
