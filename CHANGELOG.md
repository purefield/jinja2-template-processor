# Changelog

All notable changes to this project are documented in this file.

## Unreleased

- **insecure-mirrors** — Add per-mirror `insecure` flag for registries with self-signed certs or plain HTTP; sets `insecure = true` in registries.conf and generates `image.config.openshift.io/cluster` with `insecureRegistries` list via ACM ZTP extraclustermanifests, ACM CAPI ManifestWork, and ABI/IPI manifests

## v2.9.1 (2026-02-13)
- **disconnected-operatorhub** — Add `cluster.disconnected` flag and `cluster.catalogSources` for air-gapped clusters; disables default OperatorHub sources and configures custom CatalogSources via ACM ZTP extraclustermanifests, ACM CAPI ManifestWork, and ABI/IPI manifests
- **fix-tpm-test-keys** — Fix pre-existing test assertions for v2.9.0 `.yaml` extension on ConfigMap keys

## v2.9.0 (2026-02-13)
- **manifest-yaml-ext** — Add `.yaml` extension to extraclustermanifests ConfigMap data keys; assisted-service requires `.json`, `.yaml`, or `.yml` extensions on manifest filenames

## v2.8.9 (2026-02-13)
- **ztp-troubleshoot** — ZTP troubleshooting template with 15 diagnostic checks for installation progress, resource validation, and assisted-service health

## v2.8.8 (2026-02-13)
- **fix-release-script** — Fix `rg` dependency (use `grep`) and push only new release tag instead of all tags

## v2.8.7 (2026-02-13)
- **mirrors-fix** — For mirrors, always use mirror in imageContentSource template
- **release-script-fix** — Fix `rg` dependency (use `grep`), push only new tag instead of all tags

## v2.8.6 (2026-02-13)
- **fix-manifestsconfigmapref** — Move `manifestsConfigMapRef` from ClusterDeployment to AgentClusterInstall; `provisioning` and `clusterInstallRef` are mutually exclusive in the Hive CRD

## v2.8.5 (2026-02-13)
- **release-script** — Updated `clusterfile-editor.sh release` to match full "ship it" process: sync all 5 version locations, commit, tag, push, build, deploy, restart, verify healthz

## v2.8.4 (2026-02-13)
- **tpm-disk-encryption** — Updated MachineConfig with AES-CBC-ESSIV cipher, volume wipe, and XFS root filesystem
- **ztp-manifestsconfigmapref** — Fix ACM ZTP `manifestsConfigMapRef` moved under `provisioning` key

## v2.8.3 (2026-02-12)

- **tpm-install-only** — Remove ManifestWork for TPM; LUKS disk encryption is install-time only via `extraclustermanifests` (post-install wipes root disks)
- **poc-banner** — Red "Proof of Concept" ConsoleNotification banner on all managed clusters; ManifestWork in ACM ZTP/CAPI, standalone `poc-banner.yaml.tpl` for ABI/IPI

## v2.8.2 (2026-02-12)

- **tpm-install-only** — Remove ManifestWork for TPM; LUKS disk encryption is install-time only via `extraclustermanifests`. Applying LUKS MachineConfig post-install wipes root disks and reboots all nodes — too destructive for auto-delivery. TPM remains correctly handled at install time for both ZTP and CAPI flows.
- **poc-banner** — Add POC banner to all install methods: ManifestWork in ACM ZTP and CAPI templates delivers `ConsoleNotification` to managed clusters; standalone `poc-banner.yaml.tpl` for ABI/IPI (place in `manifests/` dir or `oc apply`)

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
