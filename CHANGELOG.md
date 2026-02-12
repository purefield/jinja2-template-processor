# Changelog

All notable changes to this project are documented in this file.

## Unreleased

## v2.8.1 (2026-02-12)

- **smart-storage** — Topology-aware storage class and data disk assignment: control OS→performance (etcd), worker OS→default, data→performance (ODF); compact cluster (≤5 hosts) puts data disks on control, standard cluster (≥3 workers) puts data disks on workers

## v2.8.0 (2026-02-12)

- **cluster-tpm** — Promote TPM from `plugins.kubevirt.tpm` to `cluster.tpm` as platform-agnostic master switch; auto-propagates to kubevirt VM hardware and ACM ZTP disk encryption manifests for any platform
- **kubevirt-tpm-tests** — Add test suite for KubeVirt TPM feature: enabled, disabled, omitted, and VM structure validation
- **acm-ztp-tpm-tests** — Add ACM ZTP template tests for TPM manifest generation across baremetal and kubevirt platforms

## v2.7.1 (2026-02-12)

- **cache-bust** — Dynamic cache-busting: backend injects current version into static asset URLs at serve time (`e86ffbe`)

## v2.7.0 (2026-02-12)

### Features

- **kubevirt-tpm** — Add TPM 2.0 support to KubeVirt plugin for LUKS disk encryption (`4c03fc0`)
  - Persistent TPM device, SMM features, and UEFI firmware on VMs
  - Inline MachineConfig for Clevis TPM2-based LUKS encryption in acm-ztp extraclustermanifests
- **imageDigestSources** — Replace deprecated `imageContentSources` with `imageDigestSources` in install-config (`2f0d0de`)
- **kubevirt-vlan** — Add VLAN support and restructure kubevirt VM networking (`d49c104`)
- **osimages-sync** — Replace CronJob polling with event-driven Jobs for osImages sync (`c2ba769`)
- **rhcos-osimages** — Add RHCOS osImages to ASC and per-cluster osImages ConfigMaps to ZTP/CAPI (`8893d16`)
- **kubevirt-cudn** — Use ClusterUserDefinedNetwork CRD for proper UDN Localnet support (`75de7a2`)

### Fixes

- **rhcos-iso-fix** — Fix RHCOS ISO URL: `rhcos-live.iso` -> `rhcos-live-iso.iso` (`de0e560`)
- **sno-fix** — Fix baremetal platform include to handle SNO without VIPs (`184de11`)

## v2.6.6 (2026-02-09)

- Fix UDN validation: disable IPAM for externally-managed VM IPs
- UDN networking for kubevirt
- Replace linux-bridge NAD with OVN UserDefinedNetwork in kubevirt template
- Fix arch normalization in ACM templates for RFC 1123 compliance
