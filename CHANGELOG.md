# Changelog

All notable changes to this project are documented in this file.

## Unreleased

- **ocp-on-ocp-operators** — Enhance OCP-on-OCP demo with template-driven operators: add operators sections to ocp-acm (LVM, ACM, cert-manager, ArgoCD, external-secrets), ocp-cluster2/3 (ODF); fix ocp-acm network from flat bridge to CUDN; transition manage-cluster.sh install phases from step scripts to template rendering; add operator manifest rendering to sno.setup.sh; fix kubevirt-sno.clusterfile broken flat network keys
- **kubevirt-ssd-udev** — SSD udev MachineConfig for KubeVirt VMs: forces virtual block devices to report as SSDs (rotational=0) so ODF/Ceph classifies them correctly. Included at install time via ZTP extraclustermanifests, CAPI ManifestWork, and ABI/IPI extra manifests — only when platform is kubevirt. 6 new tests

## v2.12.0 (2026-02-14)
- **siteconfig-schema** — Add ClusterInstance-inspired fields to clusterfile schema: cluster.clusterType, cluster.cpuPartitioningMode, cluster.diskEncryption (Tang), cluster.installConfigOverrides, cluster.holdInstallation, External platform; per-host bootMode, nodeLabels, automatedCleaningMode, ironicInspect, installerArgs, ignitionConfigOverride
- **siteconfig-templates** — Bidirectional conversion templates: clusterfile2siteconfig.yaml.tpl (generates ClusterInstance CR + Namespace + Secrets) and siteconfig2clusterfile.yaml.tpl (reverse mapping). Tang disk encryption MachineConfig include
- **siteconfig-template-updates** — ACM ZTP/CAPI templates consume new per-host fields (bootMode, configurable automatedCleaningMode/ironicInspect, installerArgs, ignitionConfigOverride annotations); holdInstallation in AgentClusterInstall; cpuPartitioningMode in install-config.yaml.tpl
- **siteconfig-tests** — 23 new tests: cpuPartitioningMode in install-config, per-host bootMode/automatedCleaningMode/ironicInspect/installerArgs/ignitionConfigOverride in ZTP BareMetalHost, holdInstallation in ACI, Tang disk encryption, ClusterInstance template (SNO, HA, fields, secrets)
- **siteconfig-examples** — SNO clusterfile with clusterType/cpuPartitioningMode; baremetal with bootMode/nodeLabels; new siteconfig-sno.clusterfile example; README + ACM README updated with ClusterInstance use case
- **siteconfig-template-fixes** — Fix regex_replace crash in siteconfig2clusterfile (use Jinja2 string ops); DRY BMC URL into shared bmc-url.yaml.tpl include; add External platform include; fix missing default on bmc.version; remove default-value noise from examples

## v2.11.0 (2026-02-14)
- **plugin-colocation** — Restructure operator plugins: move schema + templates from scattered `schema/plugins/` and `templates/plugins/` to co-located `plugins/operators/<name>/` directory. Each operator is self-contained with schema.json, manifests.yaml.tpl, and policy.yaml.tpl
- **operator-lvm** — LVM Storage (LVMS) operator plugin: Namespace, OperatorGroup, Subscription, LVMCluster CR with configurable deviceClasses, thinPoolConfig, deviceSelector. ACM Policy template for managed clusters
- **operator-odf** — OpenShift Data Foundation operator plugin: Subscription, StorageCluster CR with configurable storageDeviceSets, ConsolePlugin. ACM Policy template for managed clusters
- **operator-acm** — Advanced Cluster Management hub operator plugin: Namespace, OperatorGroup, Subscription, MultiClusterHub, AgentServiceConfig (storage sizes), Provisioning CR
- **operator-cert-manager** — cert-manager operator plugin: Namespace, OperatorGroup, Subscription. ACM Policy template for managed clusters
- **operator-external-secrets** — external-secrets operator plugin: Subscription (global scope, openshift-operators). ACM Policy template for managed clusters
- **operator-integration** — All 6 operators integrated into operators.yaml.tpl (standalone), install-config.yaml.tpl (ABI/IPI extra manifests), acm-ztp.yaml.tpl and acm-capi-m3.yaml.tpl (ACM Policy). All operators support optional channel, source, and approval override
- **operator-ui** — Operators sub-menu in plugins UI section with collapsible enable/disable fieldsets per operator
- **operator-tests** — 23 new tests covering all operators: defaults, custom channels/sources, disabled state, device classes (LVM), storage clusters (ODF), ACM hub config, ACM ZTP policies, multi-operator rendering
- **example-clusterfiles** — ACM hub SNO example with LVM + ACM + cert-manager + ArgoCD (bootstrap) + external-secrets; updated SNO example with LVM + ArgoCD

## v2.10.0 (2026-02-14)
- **operator-schema** — Operator plugin schema (`schema/plugins/operators/argocd.schema.json`) with ArgoCD properties and smart defaults; referenced from main clusterfile schema
- **operator-argocd-templates** — ArgoCD DRY includes: manifests.yaml.tpl (Namespace, OperatorGroup, Subscription, ArgoCD CR) and policy.yaml.tpl (ACM Policy + ConfigurationPolicy + PlacementBinding)
- **operator-integration** — ArgoCD operator integrated into install-config.yaml.tpl (extra manifests), acm-ztp.yaml.tpl and acm-capi-m3.yaml.tpl (ACM Policy); standalone operators.yaml.tpl for direct apply
- **operator-tests** — 11 tests for ArgoCD operator plugin covering defaults, customization, RBAC, disabled state, install-config, ACM ZTP policy, and bootstrap
- **plugin-restructure** — Move operators and platforms into `templates/plugins/` and `schema/plugins/` for clear isolation; each plugin self-contained in its own directory, ready for future extraction into separate repos
- **argocd-bootstrap** — App-of-apps pattern: ArgoCD Application CR that bootstraps further operators from a git repo; works in standalone manifests (ABI) and ACM Policy (ZTP/CAPI); supports autoSync with self-heal and pruning

## v2.9.3 (2026-02-14)
- **template-consolidation** — Extract shared includes for POC banner ManifestWork and os-images-sync (SA + CRB + Job); DRY insecure registries Image config in acm-capi-m3; net -69 lines of duplication
- **kubevirt-install-config** — Add kubevirt platform includes for install-config.yaml.tpl; maps to baremetal (VIPs) or none (SNO) for UPI/agent-based installs
- **multi-doc-yaml** — Fix multi-document YAML handling in CLI and web app; wrap multiple documents as a YAML list for single-document output
- **graceful-errors** — Pre-render validation for platform compatibility and required fields; transform raw Jinja2 UndefinedError into actionable messages with field hints for both CLI and UI
- **design-principles** — Add DRY, small functions, smart defaults design principles to CLAUDE.md

## v2.9.2 (2026-02-13)
- **insecure-mirrors** — Add per-mirror `insecure` flag for registries with self-signed certs or plain HTTP; sets `insecure = true` in registries.conf and generates `image.config.openshift.io/cluster` with `insecureRegistries` list via ACM ZTP extraclustermanifests, ACM CAPI ManifestWork, and ABI/IPI manifests
- **cluster-overview-update** — Add TPM, disconnected, insecure mirrors, catalog sources, secondary networks, and files required sections to cluster overview preview

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
