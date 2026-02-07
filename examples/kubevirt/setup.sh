#!/bin/bash
# Cluster Setup — Multi-node OCP on OpenShift Virtualization
# Creates VMs on a virtualization cluster, then provisions via ACM (ZTP or CAPI)
#
# Usage: ./setup.sh <clusterfile> [bootDelivery] [api]
#   clusterfile   - path to the cluster definition file
#   bootDelivery  - bmc (default) or iso
#   api           - assisted (default) or capi

export DEBUG=on
source ../../tools/format.sh
__ "Creating OCP Cluster on OpenShift Virtualization" 2
_? "What cluster.file should we use?" clusterfileSrc "" $1
_? "What boot delivery (bmc,iso)?" bootDelivery "bmc" $2
_? "What api to use (assisted,capi)?" api "assisted" $3
if [ "empty$clusterfileSrc" == "empty" ]; then __ "Missing Cluster File" error; exit 1; fi
if [ ! -s "$clusterfileSrc" ]; then __ "Cluster File $clusterfileSrc not found or empty" error; exit 1; fi
export CLUSTER=$(cat $clusterfileSrc | yq '.cluster.name' -r)
export NAMESPACE=$CLUSTER-cluster
export processor=../../jinja2-template-processor
clusterfile=$CLUSTER.generated.clusterfile
version=$(cat $clusterfileSrc | yq -r '.cluster.version')
bmc=$([[ "$bootDelivery" != "iso" ]] && echo 1 || echo "")
redfish=$(cat $clusterfileSrc | yq -r '.hosts[].bmc.vendor' | head -n1)

__ "Switch context to virtualization cluster" 4
export KUBECONFIG=~/.kube/kubeconfig.virt
oc whoami || oc login --web

noBMC=""
if [[ $bmc ]]; then
__ "Using BMC" 4
__ "Export Virt cluster kubevirt-redfish route" 3
_: "oc -n $redfish get route $redfish -o jsonpath='{.spec.host}'"
export redfishUrl=$OUTPUT
__ "url: $redfishUrl" ok
params=" -p 'hosts.*.bmc.address=$redfishUrl'"
else
noBMC=" | grep -v 'bmc:' "
fi

__ "Generated clusterfile file" 3
if [[ ! -s "$clusterfile" || "$clusterfileSrc" -nt "$clusterfile" ]]; then
__ "Generated file missing or older than src file" 4
# generate mac addresses
__ "Generate random MAC-addresses in cluster range" 4
export RANGE_START=$(oc get cm/kubemacpool-mac-range-config -n openshift-cnv -o=jsonpath='{.data.RANGE_START}')
export RANGE_END=$(oc get cm/kubemacpool-mac-range-config -n openshift-cnv -o=jsonpath='{.data.RANGE_END}')
_: "cat $clusterfileSrc | $processor/generate-mac-in-range.sh > $clusterfile"
else
__ "Generated file exists already" OK
fi

___ "Is DNS setup?" 2
_: "$processor/process.py $clusterfile $processor/templates/test-dns.sh.tpl -s $processor/schema/clusterfile.schema.json | bash"

__ "Create project, networking and virtual machines for cluster $CLUSTER" 3
_: "$processor/process.py -p 'bootDelivery=$bootDelivery' $clusterfile $processor/templates/kubevirt-cluster.yaml.tpl $noBMC -s $processor/schema/clusterfile.schema.json | oc apply -f -"

__ "Switch context to acm hub cluster" 4
export KUBECONFIG=~/.kube/kubeconfig.acm
oc whoami || oc login --web
if [ "$api" = "assisted" ]; then
__ "Create managed cluster in ACM using ZTP" 3
_: "$processor/process.py$params $clusterfile $processor/templates/acm-ztp.yaml.tpl $noBMC -s $processor/schema/clusterfile.schema.json | oc apply -n $CLUSTER -f -"
elif [ "$api" = "capi" ]; then
__ "Create managed cluster in ACM using CAPI" 3
_: "$processor/process.py$params $clusterfile $processor/templates/acm-capi-m3.yaml.tpl -s $processor/schema/clusterfile.schema.json | oc apply -n $CLUSTER -f -"
else
  __ "Invalid API selected. Chose assisted or capi" error
  exit 1
fi

__ "Wait for namespace $CLUSTER" 4
oo 1 "oc get namespace $CLUSTER -o name --no-headers | wc -l"
if [ "$api" = "assisted" ]; then
__ "Wait for infraenv $CLUSTER" 4
oo 1 "oc get infraenv $CLUSTER -n $CLUSTER -o name --no-headers | wc -l"
elif [ "$api" = "capi" ]; then
___ "Check for cluster state" 30
fi
__ "Check on BMH" 3
_: oc get bmh -n $CLUSTER

if [[ ! $bmc ]]; then
__ "Wait for the ClusterImageSet to be available for version $version" 4
oo 1 "oc get ClusterImageSet img$version-*-appsub --no-headers=true -o name | wc -l"
__ "Wait for discovery iso source image to be available for $version" 4
oo 1 "oc exec assisted-image-service-0 -n multicluster-engine -- ls /data/ 2>/dev/null | grep rhcos-full-iso-$(echo $version | cut -d\. -f1-2) | wc -l"

__ "Wait for isoDownloadURL" 4
_: oc wait infraenv $CLUSTER -n $CLUSTER --for=jsonpath='{.status.isoDownloadURL}'
imageUrl=$(oc get infraenv $CLUSTER -n $CLUSTER -o=jsonpath='{.status.isoDownloadURL}')

__ "Provide discovery iso $imageUrl to VMs" 3
_: "$processor/process.py -p 'imageUrl=$imageUrl' $clusterfile $processor/templates/kubevirt-install-iso.yaml.tpl -s $processor/schema/clusterfile.schema.json | oc apply -f -"
fi
