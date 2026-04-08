{%- set hasCustomOsImages = cluster.osImages is defined and cluster.osImages.isoUrl is defined -%}
{%- set rhcosPath = "pre-release/" + cluster.version if "-" in cluster.version else majorMinor + "/latest" -%}
{%- set osIsoUrl = cluster.osImages.isoUrl if hasCustomOsImages else "https://mirror.openshift.com/pub/openshift-v4/" + imageArch + "/dependencies/rhcos/" + rhcosPath + "/rhcos-live-iso." + imageArch + ".iso" -%}
{%- set osRootFSUrl = cluster.osImages.rootFSUrl if hasCustomOsImages else "https://mirror.openshift.com/pub/openshift-v4/" + imageArch + "/dependencies/rhcos/" + rhcosPath + "/rhcos-live-rootfs." + imageArch + ".img" -%}
- kind: ServiceAccount
  apiVersion: v1
  metadata:
    name: os-images-sync
    namespace: {{ cluster.name }}
- kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: os-images-sync-{{ cluster.name }}
  subjects:
    - kind: ServiceAccount
      name: os-images-sync
      namespace: {{ cluster.name }}
  roleRef:
    kind: ClusterRole
    name: os-images-sync
    apiGroup: rbac.authorization.k8s.io
- kind: Job
  apiVersion: batch/v1
  metadata:
    name: os-images-sync
    namespace: {{ cluster.name }}
  spec:
    ttlSecondsAfterFinished: 300
    backoffLimit: 3
    template:
      spec:
        serviceAccountName: os-images-sync
        restartPolicy: Never
        containers:
          - name: sync
            image: registry.redhat.io/openshift4/ose-cli-rhel9:latest
            command:
              - /bin/sh
              - -c
              - |
                set -e
                VERSION="{{ cluster.version }}"
                EXISTS=$(oc get agentserviceconfig agent \
                  -o go-template='{% raw %}{{range .spec.osImages}}{{if eq .version "{% endraw %}'"$VERSION"'{% raw %}"}}found{{end}}{{end}}{% endraw %}')
                if [ "$EXISTS" = "found" ]; then
                  echo "osImage for $VERSION already present, skipping"
                  exit 0
                fi
                oc patch agentserviceconfig agent --type json \
                  -p '[{"op":"add","path":"/spec/osImages/-","value":{"openshiftVersion":"{{ majorMinor }}","version":"{{ cluster.version }}","cpuArchitecture":"{{ imageArch }}","url":"{{ osIsoUrl }}","rootFSUrl":"{{ osRootFSUrl }}"}}]'
                echo "Added osImage for $VERSION"
