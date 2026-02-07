#!/bin/bash
# SNO Setup — Single Node OpenShift on OpenShift Virtualization
# Creates a VM on a virtualization cluster, then installs via agent-based installer
#
# Usage: ./sno.setup.sh <clusterfile>
#   clusterfile - path to the cluster definition file

source ../../tools/format.sh
__ "Create Single Node OpenShift cluster using Agent Based Install" 2
_? "What cluster.file should we use?" clusterfileSrc "" $1
if [ "empty$clusterfileSrc" == "empty" ]; then __ "Missing Cluster File" error; exit 1; fi
if [ ! -s "$clusterfileSrc" ]; then __ "Cluster File $clusterfileSrc not found or empty" error; exit 1; fi
export CLUSTER=$(cat $clusterfileSrc | yq '.cluster.name' -r)
export NAMESPACE=$CLUSTER-cluster
export processor=../../jinja2-template-processor
clusterfile=$CLUSTER.generated.clusterfile
__ "Switch context to virtualization cluster" 4
export KUBECONFIG=~/.kube/kubeconfig.virt

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

__ "Create configuration files" 3
__ "agent-config.yaml" 4
_: "$processor/process.py $clusterfile $processor/templates/agent-config.yaml.tpl -s $processor/schema/clusterfile.schema.json > agent-installer/agent-config.yaml"
__ "install-config.yaml" 4
_: "$processor/process.py $clusterfile $processor/templates/install-config.yaml.tpl -s $processor/schema/clusterfile.schema.json > agent-installer/install-config.yaml"

__ "Create project, networking and virtual machines for cluster $CLUSTER" 3
_: "$processor/process.py $clusterfile $processor/templates/kubevirt-cluster.yaml.tpl -s $processor/schema/clusterfile.schema.json | oc apply -f -"

__ "Create iso" 3
_: ../../agent-installer/openshift-install.sh agent-installer/
