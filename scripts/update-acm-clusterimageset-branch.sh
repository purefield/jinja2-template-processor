#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-hive-clusterimagesets}"
SUBSCRIPTION="${SUBSCRIPTION:-hive-clusterimagesets-subscription-fast-0}"
ACM_NAMESPACE="${ACM_NAMESPACE:-open-cluster-management}"
ACM_SUBSCRIPTION="${ACM_SUBSCRIPTION:-acm-operator-subscription}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

require_cmd oc

current_context="$(oc config current-context 2>/dev/null || true)"
if [[ -z "${current_context}" ]]; then
  echo "error: no current oc context" >&2
  exit 1
fi

acm_channel="$(oc -n "${ACM_NAMESPACE}" get subscription "${ACM_SUBSCRIPTION}" -o jsonpath='{.spec.channel}')"
if [[ -z "${acm_channel}" ]]; then
  echo "error: unable to read ACM subscription channel from ${ACM_NAMESPACE}/${ACM_SUBSCRIPTION}" >&2
  exit 1
fi

case "${acm_channel}" in
  release-*)
    target_branch="${acm_channel/release-/backplane-}"
    ;;
  *)
    echo "error: unsupported ACM channel format: ${acm_channel}" >&2
    exit 1
    ;;
esac

current_branch="$(oc -n "${NAMESPACE}" get subscription "${SUBSCRIPTION}" -o jsonpath='{.metadata.annotations.apps\.open-cluster-management\.io/git-branch}')"

echo "Context: ${current_context}"
echo "ACM channel: ${acm_channel}"
echo "Current ClusterImageSet branch: ${current_branch:-<unset>}"
echo "Target ClusterImageSet branch: ${target_branch}"

if [[ "${current_branch}" == "${target_branch}" ]]; then
  echo "No update needed."
  exit 0
fi

oc -n "${NAMESPACE}" annotate subscription "${SUBSCRIPTION}" \
  apps.open-cluster-management.io/git-branch="${target_branch}" \
  --overwrite

echo "Updated ${NAMESPACE}/${SUBSCRIPTION} to ${target_branch}."
echo "Watch reconciliation with:"
echo "  oc -n ${NAMESPACE} get subscription ${SUBSCRIPTION} -w"
