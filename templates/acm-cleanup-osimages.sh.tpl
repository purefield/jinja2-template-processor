{#- @meta
name: acm-cleanup-osimages.sh
description: Cleanup leftover os-images ConfigMaps and CronJob from previous sync approach
type: clusterfile
category: acm
platforms:
  - baremetal
  - kubevirt
requires:
  - cluster.name
relatedTemplates:
  - acm-asc.yaml.tpl
-#}
#!/bin/bash
# Cleanup os-images ConfigMaps and CronJob from previous polling approach
set -euo pipefail

echo "Deleting os-images ConfigMaps across all namespaces"
oc delete configmap -l app=assisted-service-os-images --all-namespaces || true

echo "Deleting os-images-sync CronJob (if exists)"
oc delete cronjob os-images-sync -n multicluster-engine || true

echo "Cleanup complete"
