# Clusterfile Editor Changelog

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
