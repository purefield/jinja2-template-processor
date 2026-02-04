# Clusterfile Editor Changelog

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
