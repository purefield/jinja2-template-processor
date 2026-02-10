#!/bin/bash
# Cluster Teardown — Remove OCP on OpenShift Virtualization
# Deletes VMs, CUDN/NAD, PVCs, and namespace on the virt cluster,
# then removes the managed cluster from ACM hub.
#
# Usage: ./teardown.sh <clusterfile> [api]
#   clusterfile - path to the cluster definition file
#   api         - assisted (default) or capi

source ../../tools/format.sh
__ "Tearing down OCP Cluster on OpenShift Virtualization" 2
_? "What cluster.file should we use?" clusterfileSrc "" $1
_? "What api was used (assisted,capi)?" api "assisted" $2
if [ "empty$clusterfileSrc" == "empty" ]; then __ "Missing Cluster File" error; exit 1; fi
if [ ! -s "$clusterfileSrc" ]; then __ "Cluster File $clusterfileSrc not found or empty" error; exit 1; fi
export CLUSTER=$(cat $clusterfileSrc | yq '.cluster.name' -r)
export NAMESPACE=$CLUSTER-cluster
export processor=../../jinja2-template-processor
clusterfile=$CLUSTER.generated.clusterfile
if [ ! -s "$clusterfile" ]; then clusterfile=$clusterfileSrc; fi
netType=$(cat $clusterfile | yq -r '.plugins.kubevirt.networkType // "cudn"')
netName="$CLUSTER-vmnet"

__ "Switch context to acm hub cluster" 4
export KUBECONFIG=~/.kube/kubeconfig.acm
oc whoami || oc login --web

__ "Delete managed cluster from ACM" 3
if [ "$api" = "assisted" ]; then
_: "$processor/process.py $clusterfile $processor/templates/acm-ztp.yaml.tpl -s $processor/schema/clusterfile.schema.json | oc delete --ignore-not-found -f -"
elif [ "$api" = "capi" ]; then
_: "$processor/process.py $clusterfile $processor/templates/acm-capi-m3.yaml.tpl -s $processor/schema/clusterfile.schema.json | oc delete --ignore-not-found -f -"
fi

__ "Switch context to virtualization cluster" 4
export KUBECONFIG=~/.kube/kubeconfig.virt
oc whoami || oc login --web

__ "Stop VMs in $NAMESPACE" 3
_: "oc get vm -n $NAMESPACE -o name 2>/dev/null | xargs -r oc delete -n $NAMESPACE --wait=true"

if [ "$netType" = "cudn" ]; then
__ "Delete ClusterUserDefinedNetwork $netName" 3
_: "oc delete clusteruserdefinednetwork $netName --ignore-not-found --wait=true"
fi

__ "Delete namespace $NAMESPACE" 3
_: "oc delete namespace $NAMESPACE --ignore-not-found --wait=true"

__ "Teardown complete for $CLUSTER" ok
