- kind: ManifestWork
  apiVersion: work.open-cluster-management.io/v1
  metadata:
    name: poc-banner
    namespace: {{ cluster.name }}
  spec:
    workload:
      manifests:
        - apiVersion: console.openshift.io/v1
          kind: ConsoleNotification
          metadata:
            name: poc-banner
          spec:
            text: "This is a Proof of Concept and not for production use"
            location: BannerTop
            color: "#fff"
            backgroundColor: "#e00"
