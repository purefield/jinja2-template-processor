# Clusterfile Editor Changelog

## 3.4.0
- **Collateral Kit**: Executive one-pager, 11-slide deck, demo script, architecture SVG, and comparison matrix in `docs/collateral/`
- **File Externalization Docs**: Collateral highlights that pull secrets, SSH keys, certificates, and credentials are externalized as file paths loaded at render time
- **ESO Clarification**: ESO documented as day-2 on-cluster operator, not part of the rendering process

## 3.3.0
- **ESO Vault Config**: ClusterSecretStore config template for Vault/OpenBao backend with Kubernetes auth. Default cert-manager secretStore changed to vault. ESO enabled on all example clusterfiles

## 3.2.1
- **KubeVirt CPU Request**: Increase VM CPU request from 2 to 4 to reduce resource contention

## 3.2.0
- **cert-manager Self-Check**: CertManager CR with `--dns01-recursive-nameservers-only` and recursive nameservers (default 8.8.8.8, 1.1.1.1) for reliable DNS-01 preflight checks. Conditional `cnameStrategy: Follow` on ClusterIssuer solver

## 3.1.0
- **SiteConfig KubeVirt**: KubeVirt platform now supported in siteconfig template — maps to BareMetal platformType in ClusterInstance CR

## 3.0.0
- **Kubernetes List Wrapper**: Multi-document YAML output (siteconfig, disconnected install-config) now wrapped in `kind: List` resource — output is directly `kubectl apply -f` / `oc apply -f` compatible. Single-doc templates unchanged

## 2.15.0
- **Platform Plugin Move**: Platform templates (aws, azure, gcp, vsphere, openstack, ibmcloud, nutanix, baremetal, kubevirt, none, external) moved from `templates/plugins/platforms/` to `plugins/platforms/` — all plugins now co-located under `plugins/`

## 2.14.0
- **Extract Plugin Schemas**: Operator schemas (ArgoCD, LVM, ODF, ACM, cert-manager, external-secrets) extracted from monolithic schema to `plugins/operators/<name>/schema.json` — auto-discovered and merged at load time
- **cert-manager LetsEncrypt**: Template-driven LetsEncrypt configuration with ExternalSecret, ClusterIssuer, and Certificate resources for DNS-01 validation via Route53
- **SecretStore Bootstrap**: Vault ClusterSecretStore bootstrap script with Kubernetes auth

## 2.13.0
- **OCP-on-OCP Operators**: Template-driven operator deployment for OCP-on-OCP demo — clusterfile operators sections for LVM, ACM, cert-manager, ArgoCD, external-secrets (hub) and ODF (managed clusters); manage-cluster.sh install phases transitioned from step scripts to template rendering
- **KubeVirt SSD Udev**: Install-time MachineConfig that forces virtual block devices to report as SSDs — included automatically for kubevirt platform via ZTP extraclustermanifests, CAPI ManifestWork, and ABI extra manifests
- **KubeVirt SNO Fix**: Fix broken flat network keys in kubevirt-sno example clusterfile

## 2.12.0
- **SiteConfig Integration**: Bidirectional conversion between clusterfiles and SiteConfig ClusterInstance CRs — `clusterfile2siteconfig.yaml.tpl` generates ClusterInstance + Namespace + Secrets; `siteconfig2clusterfile.yaml.tpl` does the reverse
- **ClusterInstance Fields**: New schema fields from ClusterInstance data model — clusterType, cpuPartitioningMode, diskEncryption (Tang), holdInstallation, External platform; per-host bootMode, nodeLabels, automatedCleaningMode, ironicInspect, installerArgs, ignitionConfigOverride
- **Template Enrichment**: ACM ZTP/CAPI templates consume all new per-host fields; install-config supports cpuPartitioningMode; Tang disk encryption MachineConfig include
- **DRY BMC URLs**: Shared `bmc-url.yaml.tpl` include for vendor-specific Redfish URL construction across all templates

## 2.11.0
- **6 Operator Plugins**: LVM, ODF, ACM, cert-manager, external-secrets join ArgoCD — each with smart defaults, optional channel/source/approval overrides, standalone manifests (ABI) and ACM Policy (ZTP/CAPI)
- **Plugin Co-location**: Operators restructured to `plugins/operators/<name>/` — schema, manifests, and policy templates co-located per operator
- **Operators UI**: New operators sub-section in Plugins tab with collapsible enable/disable fieldsets — check to enable, expand to configure
- **ACM Hub Example**: Full ACM hub SNO clusterfile with LVM + ACM + cert-manager + ArgoCD (bootstrap) + external-secrets

## 2.10.0
- **Operator Plugin Architecture**: New `plugins.operators` section with ArgoCD as first operator — just `argocd: {}` for full setup with smart defaults
- **Plugin Isolation**: Operators and platforms restructured into `templates/plugins/` and `schema/plugins/` — each plugin self-contained, ready for separate repos
- **ArgoCD ACM Policy**: Managed clusters get ArgoCD via ACM Policy (ZTP + CAPI); standalone clusters via extra manifests (ABI)
- **ArgoCD Bootstrap**: App-of-apps pattern — ArgoCD Application CR that manages further operators from a git repo with auto-sync, self-heal, and pruning

## 2.9.3
- **Template Consolidation**: Extract shared includes for POC banner ManifestWork and os-images-sync; DRY insecure registries; net -69 lines of duplication
- **KubeVirt Install Config**: Add kubevirt platform includes for install-config.yaml.tpl — maps to baremetal (VIPs) or none (SNO) for UPI/agent-based installs
- **Multi-Document YAML**: Fix multi-doc rendering in CLI and UI; wrap multiple documents as YAML list
- **Graceful Errors**: Pre-render validation for platform compatibility and required fields; actionable error messages for both CLI and UI

## 2.9.2
- **Insecure Mirrors**: Per-mirror `insecure` flag for self-signed certs and HTTP mirrors — sets `insecure=true` in registries.conf, generates `image.config.openshift.io/cluster` insecureRegistries across ZTP, CAPI, and ABI/IPI
- **Cluster Overview Update**: Add TPM encryption, disconnected, insecure mirrors, catalog sources, secondary networks, and files required sections to cluster overview preview

## 2.9.1
- **Disconnected Clusters**: Add `cluster.disconnected` flag and `cluster.catalogSources` for air-gapped installations — disables default OperatorHub sources, configures custom CatalogSources across all install methods (ZTP, CAPI, ABI/IPI)

## 2.9.0
- **Manifest Filename Fix**: Add `.yaml` extension to extraclustermanifests ConfigMap keys — assisted-service requires valid file extensions

## 2.8.9
- **ZTP Troubleshoot**: Comprehensive troubleshooting template — 15 checks for resources, conditions, agents, ISO, sync jobs, and assisted-service health

## 2.8.8
- **Release Script Fix**: Use `grep` instead of `rg`, push only new tag

## 2.8.7
- For mirrors, always use mirror


## 2.8.6
- **ZTP Fix**: Move `manifestsConfigMapRef` from ClusterDeployment to AgentClusterInstall — `provisioning` and `clusterInstallRef` are mutually exclusive

## 2.8.5
- **Release Script**: Updated `clusterfile-editor.sh release` to full ship-it process — syncs all version locations, commits, tags, pushes, builds, deploys, restarts, and verifies health

## 2.8.4
- **TPM Disk Encryption**: Updated MachineConfig with AES-CBC-ESSIV cipher, volume wipe, and XFS root filesystem
- **ZTP Fix**: Moved `manifestsConfigMapRef` under `provisioning` key


## 2.8.3
- **TPM Install-Time Only**: Removed ManifestWork — LUKS post-install wipes root disks
- **POC Banner**: Red "Proof of Concept" ConsoleNotification on all managed cluster consoles
  - ACM ZTP/CAPI: auto-delivered via ManifestWork
  - ABI/IPI: standalone `poc-banner.yaml.tpl` for `manifests/` dir or `oc apply`

## 2.8.2
- **TPM Install-Time Only**: LUKS disk encryption via `extraclustermanifests` at install time only
  - Removed ManifestWork — applying LUKS MachineConfig post-install wipes root disks (destructive)
  - TPM correctly handled at install time for ZTP (extraclustermanifests ConfigMap)
  - For running clusters, TPM encryption must be applied manually with full awareness of data loss
- **POC Banner**: Red "Proof of Concept" banner on all managed cluster consoles
  - ACM ZTP and CAPI: ManifestWork delivers ConsoleNotification to managed clusters automatically
  - ABI/IPI: Standalone `poc-banner.yaml.tpl` template — place in `manifests/` dir or `oc apply`
  - All install methods covered: ACM ZTP, ACM CAPI, ABI, IPI

## 2.8.1
- **Smart Storage**: Topology-aware storage class and data disk assignment
  - Control plane OS disks use performance storage class (fast I/O for etcd)
  - Worker OS disks use default storage class (capacity-oriented)
  - Data disks always use performance storage class (ODF/Ceph)
  - Compact cluster (≤5 hosts): data disks on control nodes (ODF collocated)
  - Standard cluster (≥3 workers): data disks on worker nodes (dedicated ODF)
  - Gap topology: no data disks when insufficient nodes for ODF

## 2.8.0
- **Cluster-Level TPM**: `cluster.tpm` replaces `plugins.kubevirt.tpm` as platform-agnostic master switch
  - Enables LUKS disk encryption MachineConfig in ACM/ZTP for any platform (baremetal, kubevirt, etc.)
  - On kubevirt, automatically adds persistent vTPM device with SMM and UEFI firmware to VMs
  - Schema updated: `cluster.tpm` boolean (default: false); removed from `plugins.kubevirt`

## 2.7.1
- **Cache Busting**: Static asset URLs (`?v=`) now dynamically use the current app version
  - Backend replaces hardcoded `?v=` params in index.html at serve time
  - No more stale CSS/JS after upgrades

## 2.7.0
- **KubeVirt TPM Support**: Persistent TPM 2.0 device on VMs for LUKS disk encryption
  - `tpm: persistent: true` in domain.devices, SMM features, UEFI firmware with persistent EFI
  - Inline MachineConfig for Clevis TPM2-based LUKS encryption in acm-ztp extraclustermanifests
  - `plugins.kubevirt.tpm` boolean in schema (default: false)
- **imageDigestSources**: Replace deprecated `imageContentSources` with `imageDigestSources` in install-config
  - Deprecated in OCP 4.14, warning from 4.19 onward
- **KubeVirt VLAN Networking**: VLAN support with restructured kubevirt VM networking
- **CUDN Localnet**: ClusterUserDefinedNetwork CRD for proper UDN Localnet support with linux-bridge fallback
- **RHCOS osImages**: RHCOS osImages in ASC and per-cluster osImages ConfigMaps for ZTP/CAPI
- **osImages Sync**: Event-driven Jobs replace CronJob polling for osImages sync
- **Fix**: RHCOS ISO URL corrected (`rhcos-live.iso` → `rhcos-live-iso.iso`)
- **Fix**: Baremetal platform include handles SNO without VIPs

## 2.6.6
- **UDN Networking**: Replace linux-bridge NAD with OVN UserDefinedNetwork in kubevirt template
  - No node-level bridge configuration needed — OVN handles the overlay
  - Removed `bridge` field from schema and sample clusterfiles

## 2.6.5
- **Editable Filename**: Click the filename in the header to rename
  - Inline input with Enter to save, Escape to cancel
  - Persists to localStorage, used in page title and downloads
  - Works for new documents, loaded files, and samples

## 2.6.4
- **No Browser Dialogs**: All `prompt()`, `alert()`, `confirm()` replaced with inline UI
  - Add host: inline FQDN input with validation errors
  - Duplicate/rename host: inline input replaces hostname label (Enter/Escape)
  - Remove host: immediate delete with undo toast
  - New document and revert all: click-twice-to-confirm pattern

## 2.6.3
- **Tier Map Editor**: `storageClass` rendered as uniform key-value list with enum tier selector
  - Each row: `[tier name]` `[StorageClassName input]` `[× remove]`
  - Add row: dropdown with predefined tiers (default, performance) + Other for custom names
  - Tier keys shown in monospace for clear identification
- **Dynamic Tier Dropdowns**: `storageMapping` os/data fields auto-populate from `storageClass` keys
  - `x-options-from-keys` schema annotation resolves dropdown options from live data
  - Adding a custom tier in `storageClass` immediately appears in tier selection dropdowns
  - Enum + Other pattern for consistent UX across tier definition and usage

## 2.6.2
- **Custom Storage Class Editor**: `storageClass` inline key-value editing with YAML persistence

## 2.6.1
- **Storage Mapping Enums**: `storageMapping` os/data tier fields now use `enum: ["default", "performance"]`
  - Editor renders dropdowns instead of free-text inputs
  - Validation catches typos in tier labels

## 2.6.0
- **KubeVirt Platform Support**: Full OpenShift Virtualization cluster provisioning
  - `kubevirt-cluster.yaml.tpl` generates Namespace, NetworkAttachmentDefinition, PVCs, and VirtualMachines
  - `kubevirt-install-iso.yaml.tpl` generates DataVolume for discovery ISO boot
  - Three sample clusterfiles: full (3+2), compact (3 control), SNO
  - kubevirt-redfish BMC vendor for virtual BMC emulation
- **Machine Resource Specifications**: Platform-agnostic `cluster.machine` with per-role defaults
  - `cluster.machine.control` / `cluster.machine.worker` for CPU, sockets, memory, storage
  - Per-host `hosts.<name>.machine` overrides for exceptions
  - Schema `$defs/machineSpec` reusable definition
  - vSphere and Nutanix templates updated with `cluster.machine` fallback
- **Storage Class Mapping**: Data-driven storage tier assignment in `plugins.kubevirt`
  - `storageClass.default` / `storageClass.performance` define available tiers
  - `storageMapping` maps roles to tiers for OS and data disks
  - Control plane gets performance (etcd), workers get default (capacity)
- **Editor Integration**: KubeVirt in plugin page, template page, and platform selector
- **All examples bumped to OpenShift 4.21.0**

## 2.5.8
- **ACM Template Cross-Links**: All 6 ACM templates now include `relatedTemplates` metadata
  - acm-ztp, acm-capi-m3, acm-asc, acm-creds, acm-clusterimageset, acm-clusterimagesets-sub
  - Full bidirectional links for template discovery in the editor UI
  - Added `docs` URLs for upstream documentation references

## 2.5.7
- **ACM ClusterImageSet Template**: Version management for ACM/MCE cluster deployments
  - Matches stolostron/acm-hive-openshift-releases upstream format exactly
  - Mirror-aware releaseImage for disconnected environments
  - Name convention matches ZTP imageSetRef (`img{version}-{arch}-appsub`)
- **ACM ClusterImageSets Subscription**: Auto-sync template for connected environments
  - Namespace, Application, Channel, Subscription resources
  - Points to backplane-2.10 branch of acm-hive-openshift-releases
  - Configurable channel (fast/stable/candidate)

## 2.5.6
- **Privacy & Trust Indicators**: Enterprise trust signals for security-conscious environments
  - Green "Local only" badge in header with lock icon — always visible
  - Dedicated Privacy & Trust section with four detail panels:
    - Data Stays Local — no external connections, telemetry, or cloud dependencies
    - Credential Handling — file path references only, never transmitted
    - Auditable Output — human-readable scripts, review before execution
    - Deployment Options — local, air-gapped, CLI-only modes
  - Enhanced file-path field tooltips reinforcing local-only processing

## 2.5.5
- **Pre-Check Template Restructure**: Modular body includes with composable master
  - Check logic in `includes/pre-check/` body files (files, dns, network, ntp, registry, bmc)
  - Standalone modules are thin wrappers: common + body + summary
  - Master `pre-check.sh.tpl` composes all bodies via include — no duplicated logic
  - 91 render combinations tested (13 clusterfiles x 7 templates)

## 2.5.4
- **Cluster Overview Enhancements**: Network capacity calculations and DNS improvements
  - api-int DNS record now CNAME pointing to api record
  - Cluster network: pods per node and max nodes from host prefix
  - Service network: usable address count
  - Machine network: usable host count
  - NIC table: name and MAC grouped in nested table to prevent wrapping

## 2.5.3
- **Preview Button in Header**: One-click cluster overview preview from top menu bar
  - Eye icon button renders cluster-overview.html.tpl and opens in new tab
  - Works with any loaded clusterfile — no template selection needed

## 2.5.2
- **Cluster Overview HTML**: Self-contained HTML document replaces markdown version
  - Opens directly in any browser — no markdown viewer needed
  - Dark mode, print-friendly, responsive layout with inline CSS
  - Host cards for baremetal, compact table for IPI platforms
- **Preview Button**: HTML templates show a Preview button in the rendered output pane
  - Opens rendered HTML in a new browser tab for live preview
- **Documentation Category**: New dropdown group for documentation templates

## 2.5.1
- **Template Restyle Complete**: Remaining 7 templates restyled with YAML-leading style and Jinja whitespace flags
  - install-config, secondary-network-setup, mirror-registry-config, ACM templates, includes
  - All `if/endif/for/endfor` moved inline; whitespace flags (`{%-`/`-%}`) for tight output
- **Cluster Overview Document**: New `cluster-overview.md.tpl` template for customer-facing documentation
  - Renders clean markdown from any clusterfile (baremetal, IPI, SNO)
  - Sections: identity, topology, network, hosts, mirrors, trust, DNS records
  - Adapts layout to platform (detailed host cards vs compact table)

## 2.5.0
- **Template Restyle**: All 18 platform include templates now follow YAML-leading style
  - Every line starts with output structure; Jinja directives appended inline
  - Closing directives attach to previous YAML lines, never on their own line
  - Templates are now human-scannable — you see the YAML shape at a glance
- **Robustness Defaults**: All controlPlane/compute templates use `| default({})` for optional sub-sections
  - Agent-based clusterfiles no longer crash when IPI-specific data is absent
  - Nutanix platform guards prismCentral/prismElements/subnetUUIDs behind `is defined`
- **BMC Vendor Enum**: Added `ksushy` and `kubevirt-redfish` to schema BMC vendor enum

## 2.4.7
- **Fix Mode Field Regressions**: Bond, VLAN, and MTU toggle fixes
  - Fix bond string values like "802.3ad" being coerced to numbers
  - Disabled now omits the key from config instead of writing `false`
  - Undefined/null values default to Disabled state
  - MTU validation uses anyOf to avoid oneOf overlap between presets and custom range

## 2.4.6
- **MTU Toggle**: MTU field now uses dropdown with Default (1500), Jumbo (9000), Custom, or Disabled
  - Presets: Default (1500) for standard frames, Jumbo (9000) for high-throughput networks
  - Custom option allows manual entry (576-9216)
  - Disabled option omits MTU from config (uses system default)
  - Applies to both primary and secondary network MTU fields

## 2.4.5
- **Robust Schema Handling**: Added utility functions for safe schema resolution
  - `safeResolveSchema()` - Validates and resolves $ref with fallback
  - `getSchemaArray()` - Safely access array properties (enum, required)
  - `getRootSchema()` - Convenience accessor for root schema
- **Fix All $ref Resolutions**: Resolve $refs in all schema accesses
  - `renderField()` - Resolve before type checking
  - `renderObjectFields()` - Resolve both schema and field schemas
  - `getHostSchema()` - Resolve patternProperties
  - `renderPluginsSection()` - Resolve plugin schemas
  - `renderModeField()` - Resolve options for value input
  - `renderArrayField()` - Resolve items schema
- **Defensive Null Checks**: Added proper null/undefined guards throughout

## 2.4.4
- **Fix Plugin Forms**: Resolve $refs in anyOf/oneOf before type detection for nested objects
- **Fix Bond/VLAN Toggle**: Mode selector now properly detects enum options with $ref
- **Fix Pull Secret Validation**: Check for `.auths` key instead of just valid JSON

## 2.4.3
- **Changelog Sync**: Fixed CHANGELOG array in app.js to include 2.4.1 and 2.4.2 releases

## 2.4.2
- **Modular Pre-Check Templates**: Refactored pre-check.sh into standalone modules
  - `pre-check-files.sh.tpl` - Validate pull secret, SSH keys, trust bundle, manifests
  - `pre-check-dns.sh.tpl` - DNS forward/reverse lookups and resolver checks
  - `pre-check-network.sh.tpl` - Host connectivity, gateway, VIP availability, proxy
  - `pre-check-ntp.sh.tpl` - NTP server connectivity
  - `pre-check-registry.sh.tpl` - Container registry connectivity with auth
  - `pre-check-bmc.sh.tpl` - BMC ping and Redfish API checks
- **Comprehensive Master Template**: `pre-check.sh.tpl` now composes all modules inline
- **Conditional Rendering**: Each section only renders when relevant data exists

## 2.4.1
- **Pre-Check Script**: Added `pre-check.sh.tpl` template for pre-installation verification
  - Tests DNS forward/reverse lookups, NTP, DNS resolvers, registry access, host connectivity, BMC
  - Only includes sections when data exists (minimal output for minimal configs)
  - Warns instead of fails - documents gaps without blocking
- **Related Templates**: Templates now link to commonly-used companions via `relatedTemplates` metadata
  - Dynamic related templates section in editor UI with category icons
- **Download Fix**: Rendered template download now uses correct file extension (.yaml, .sh)
- **Test Fixes**: Fixed test imports and assertions for template API

## 2.4.0
- **Template Metadata**: Added `@meta` blocks to all templates with type, category, platforms, requires, and docs
- **Smart Template Filtering**: Template dropdown now only shows clusterfile-type templates, grouped by category
- **Template Info Display**: Selected template shows supported platforms, required fields, and documentation link
- **vSphere Static IPs**: Added support for static IP configuration in vSphere IPI (TechPreview in OCP 4.17+)
- **Dynamic Version**: Browser title and header now show version fetched from API
- **Updated vSphere Example**: Example clusterfile now demonstrates static IP configuration

## 2.3.1
- **Templates Page Simplified**: Replaced 9 platform selection buttons with single platform info card
- **Platform Info Card**: Shows current platform icon, name, and description
- **Navigation Link**: Added "Change" link to navigate directly to Cluster section for platform changes
- **Credentials Button**: Added "Load Credentials Template" button for cloud platforms (AWS, Azure, GCP, vSphere, OpenStack, IBM Cloud, Nutanix)
- **UI Polish**: Reduced platform icon size from 32px to 20px for cleaner appearance
- **Updated Template Descriptions**: install-config.yaml.tpl and creds.yaml.tpl now show proper descriptions

## 2.3.0
- **Template Consolidation**: Replaced 7 platform-specific install-config templates with unified `install-config.yaml.tpl`
- **Dynamic Includes**: Created platform-specific includes under `templates/includes/platforms/{platform}/`
  - Each IPI platform has: controlPlane.yaml.tpl, compute.yaml.tpl, platform.yaml.tpl, creds.yaml.tpl
  - Supported platforms: aws, azure, gcp, vsphere, openstack, ibmcloud, nutanix, baremetal, none
- **Credentials Template**: Added unified `creds.yaml.tpl` for CCO (Cloud Credential Operator) credential generation
- **Nutanix Support**: Added full Nutanix IPI platform support with all includes
- **Test Suite**: Added comprehensive test suite with 57 tests
  - `tests/run_tests.py` - Standalone runner (no pytest dependency)
  - `tests/test_templates.py` - Full pytest-based test suite
  - Covers all platforms, configuration options, includes, and edge cases
- **Sample Data**: Added `customer.example.nutanix-ipi.clusterfile` sample
- **Whitespace Fix**: Fixed Jinja2 `{%- set %}` whitespace stripping that broke YAML indentation

## 2.2.2
- **Cross-Navigation**: Added links between Plugins and Cluster sections for platform configuration
- **Resizable Split View**: Added draggable divider between form and editor panes with localStorage persistence
- **Plugin Filtering**: Plugins section now shows only the plugin matching cluster.platform
- **Platform Selector**: Added platform buttons with auto-template selection on Templates page
- **IPI Platforms**: Added support for AWS, Azure, GCP, OpenStack, IBM Cloud platforms
- **vSphere IPI**: Added vSphere IPI support with failure domains

## 2.2.1
- Bug fixes and stability improvements

## 2.2.0
- Enhanced form editor with real-time validation
- Improved YAML editor with syntax highlighting
- Added diff view for change tracking

## 2.1.0
- Added Template and Rendered tabs for full-page template viewing
- Auto-load template source when selecting from dropdown
- Auto-render with parameter highlighting showing changed lines
- Improved Changes section with grouped changes and clickable links
- Fixed form focus loss when editing YAML
- Enhanced filename display with modification indicator
- Real-time validation and change badge updates

## 2.0.0
- Complete UI redesign with PatternFly styling
- Split view with form editor and YAML editor
- JSON Schema-driven form generation
- Live template rendering
- Sample clusterfile loading
