#!/bin/bash
# Clusterfile Editor - Standalone HTML Builder
# Creates a single self-contained HTML file that works from file:// protocol

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/dist"
VERSION=$(cat "${SCRIPT_DIR}/APP_VERSION" 2>/dev/null || echo "2.1.0")
OUTPUT_FILE="${OUTPUT_DIR}/clusterfile-editor-${VERSION}-standalone.html"

echo "Building standalone HTML file..."
echo "Version: ${VERSION}"

mkdir -p "${OUTPUT_DIR}"

# Helper function to minify CSS (simple removal of comments and extra whitespace)
minify_css() {
    # Remove CSS comments, collapse whitespace
    sed 's|/\*[^*]*\*\+\([^/*][^*]*\*\+\)*/||g' | tr '\n' ' ' | sed 's/  */ /g'
}

# Helper function to escape content for embedding in script tags
escape_for_json() {
    python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))"
}

# Collect all CSS
echo "Collecting CSS..."
CSS_CONTENT=""
for css_file in \
    "${SCRIPT_DIR}/static/vendor/patternfly.min.css" \
    "${SCRIPT_DIR}/static/vendor/patternfly-addons.css" \
    "${SCRIPT_DIR}/static/vendor/codemirror.min.css" \
    "${SCRIPT_DIR}/static/vendor/codemirror-foldgutter.css" \
    "${SCRIPT_DIR}/static/css/app.css"; do
    if [ -f "${css_file}" ]; then
        CSS_CONTENT="${CSS_CONTENT}
/* $(basename "${css_file}") */
$(cat "${css_file}")"
    else
        echo "Warning: CSS file not found: ${css_file}"
    fi
done

# Collect all JavaScript
echo "Collecting JavaScript..."
JS_CONTENT=""
for js_file in \
    "${SCRIPT_DIR}/static/vendor/js-yaml.min.js" \
    "${SCRIPT_DIR}/static/vendor/ajv.min.js" \
    "${SCRIPT_DIR}/static/vendor/codemirror.min.js" \
    "${SCRIPT_DIR}/static/vendor/codemirror-yaml.min.js" \
    "${SCRIPT_DIR}/static/vendor/codemirror-foldcode.min.js" \
    "${SCRIPT_DIR}/static/vendor/codemirror-foldgutter.min.js" \
    "${SCRIPT_DIR}/static/vendor/codemirror-indent-fold.min.js" \
    "${SCRIPT_DIR}/static/vendor/diff.min.js" \
    "${SCRIPT_DIR}/static/vendor/nunjucks.min.js" \
    "${SCRIPT_DIR}/static/js/state.js" \
    "${SCRIPT_DIR}/static/js/validator.js" \
    "${SCRIPT_DIR}/static/js/help.js" \
    "${SCRIPT_DIR}/static/js/editor.js" \
    "${SCRIPT_DIR}/static/js/form.js" \
    "${SCRIPT_DIR}/static/js/template-renderer.js" \
    "${SCRIPT_DIR}/static/js/app.js"; do
    if [ -f "${js_file}" ]; then
        JS_CONTENT="${JS_CONTENT}
// === $(basename "${js_file}") ===
$(cat "${js_file}")"
    else
        echo "Warning: JS file not found: ${js_file}"
    fi
done

# Collect schema (with auto-discovered operator plugin schemas merged)
echo "Collecting schema..."
SCHEMA_JSON=$(python3 -c "
import json, os
with open('${REPO_ROOT}/schema/clusterfile.schema.json') as f:
    s = json.load(f)
plugins_dir = '${REPO_ROOT}/plugins/operators'
if os.path.isdir(plugins_dir):
    s.setdefault('\$defs', {})
    ops = (s.setdefault('properties', {}).setdefault('plugins', {})
            .setdefault('properties', {}).setdefault('operators', {})
            .setdefault('properties', {}))
    for d in sorted(os.listdir(plugins_dir)):
        sf = os.path.join(plugins_dir, d, 'schema.json')
        if os.path.isfile(sf):
            k = 'operator' + ''.join(p.capitalize() for p in d.split('-'))
            with open(sf) as fh:
                s['\$defs'][k] = json.load(fh)
            ops[d] = {'\$ref': f'#/\$defs/{k}'}
print(json.dumps(s))
")

# Collect samples with content
echo "Collecting samples..."
SAMPLES_JSON="["
first_sample=true
for sample_file in "${REPO_ROOT}/data/"*.clusterfile; do
    if [ -f "${sample_file}" ]; then
        filename=$(basename "${sample_file}")
        name="${filename%.clusterfile}"
        name="${name//./ }"  # Replace dots with spaces
        name="${name#customer.example.}"  # Remove prefix
        name="${name:-Basic}"  # Default name
        content=$(cat "${sample_file}" | escape_for_json)

        if [ "${first_sample}" = "true" ]; then
            first_sample=false
        else
            SAMPLES_JSON="${SAMPLES_JSON},"
        fi
        SAMPLES_JSON="${SAMPLES_JSON}
    {\"filename\": \"${filename}\", \"name\": \"${name}\", \"content\": ${content}}"
    fi
done
SAMPLES_JSON="${SAMPLES_JSON}
]"

# Collect templates with content
echo "Collecting templates..."
TEMPLATES_JSON="["
first_template=true
shopt -s nullglob
for template_file in "${REPO_ROOT}/templates/"*.tpl "${REPO_ROOT}/templates/"*.yaml.tpl; do
    if [ -f "${template_file}" ]; then
        filename=$(basename "${template_file}")
        # Extract description from first comment line if present
        description=$(head -1 "${template_file}" | grep -oP '(?<={#\s).*(?=\s#})' || echo "${filename}")
        content=$(cat "${template_file}" | escape_for_json)

        if [ "${first_template}" = "true" ]; then
            first_template=false
        else
            TEMPLATES_JSON="${TEMPLATES_JSON},"
        fi
        TEMPLATES_JSON="${TEMPLATES_JSON}
    {\"name\": \"${filename}\", \"description\": \"${description}\", \"content\": ${content}}"
    fi
done
shopt -u nullglob
TEMPLATES_JSON="${TEMPLATES_JSON}
]"

# Read the SVG logo
echo "Embedding logo..."
LOGO_SVG=""
if [ -f "${SCRIPT_DIR}/static/editor.svg" ]; then
    LOGO_SVG=$(cat "${SCRIPT_DIR}/static/editor.svg" | tr '\n' ' ')
fi

# Generate the standalone HTML
echo "Generating HTML..."
cat > "${OUTPUT_FILE}" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Clusterfile Editor (Standalone)</title>
  <style>
HTMLEOF

echo "${CSS_CONTENT}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" << 'HTMLEOF'
  </style>
</head>
<body>
  <div class="app-container">
    <!-- Header -->
    <header class="app-header">
      <div class="app-header__brand">
HTMLEOF

# Embed the logo SVG inline
if [ -n "${LOGO_SVG}" ]; then
    echo "        ${LOGO_SVG}" >> "${OUTPUT_FILE}"
else
    echo '        <span style="font-size: 24px;">📄</span>' >> "${OUTPUT_FILE}"
fi

cat >> "${OUTPUT_FILE}" << HTMLEOF
        <h1 class="app-header__title">Clusterfile Editor</h1>
        <span class="app-header__version" title="Click for changelog">v${VERSION}</span>
      </div>
      <div class="app-header__filename-area">
        <svg class="app-header__file-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="18" height="18">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
          <polyline points="14,2 14,8 20,8"/>
        </svg>
        <span class="app-header__filename">untitled.clusterfile</span>
        <span class="app-header__modified" id="modified-indicator" style="display: none;">*</span>
      </div>
      <div class="app-header__actions">
        <button class="btn btn--secondary btn--sm" id="btn-new" title="New (Ctrl+N)">New</button>
        <button class="btn btn--secondary btn--sm" id="btn-load" title="Load (Ctrl+O)">Load</button>
        <div class="dropdown">
          <button class="btn btn--secondary btn--sm" id="btn-samples">Samples ▾</button>
          <div class="dropdown__menu" id="samples-menu">
            <!-- Populated by JS -->
          </div>
        </div>
        <button class="btn btn--secondary btn--sm" id="btn-save" title="Save (Ctrl+S)">Save</button>
        <button class="btn btn--primary btn--sm" id="btn-download">Download</button>
      </div>
    </header>

    <!-- Main Content -->
    <main class="app-main">
      <!-- Sidebar -->
      <aside class="app-sidebar">
        <nav class="sidebar-nav">
          <a class="sidebar-nav__item sidebar-nav__item--active" data-section="account">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
              <circle cx="12" cy="7" r="4"/>
            </svg>
            <span>Account</span>
          </a>
          <a class="sidebar-nav__item" data-section="cluster">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M12 2L2 7l10 5 10-5-10-5z"/>
              <path d="M2 17l10 5 10-5"/>
              <path d="M2 12l10 5 10-5"/>
            </svg>
            <span>Cluster</span>
          </a>
          <a class="sidebar-nav__item" data-section="network">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <circle cx="12" cy="12" r="10"/>
              <path d="M2 12h20"/>
              <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
            </svg>
            <span>Network</span>
          </a>
          <a class="sidebar-nav__item" data-section="hosts">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
              <line x1="8" y1="21" x2="16" y2="21"/>
              <line x1="12" y1="17" x2="12" y2="21"/>
            </svg>
            <span>Hosts</span>
          </a>
          <a class="sidebar-nav__item" data-section="plugins">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M12 2v6m0 8v6M4.93 4.93l4.24 4.24m5.66 5.66l4.24 4.24M2 12h6m8 0h6M4.93 19.07l4.24-4.24m5.66-5.66l4.24-4.24"/>
            </svg>
            <span>Plugins</span>
          </a>

          <div class="sidebar-nav__divider"></div>

          <a class="sidebar-nav__item" data-section="templates">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
              <polyline points="14,2 14,8 20,8"/>
              <line x1="16" y1="13" x2="8" y2="13"/>
              <line x1="16" y1="17" x2="8" y2="17"/>
            </svg>
            <span>Templates</span>
          </a>
          <a class="sidebar-nav__item" data-section="validation">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
              <polyline points="22,4 12,14.01 9,11.01"/>
            </svg>
            <span>Validation</span>
            <span class="sidebar-nav__item-badge" style="display: none;">0</span>
          </a>
          <a class="sidebar-nav__item" data-section="changes">
            <svg class="sidebar-nav__item-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            <span>Changes</span>
            <span class="sidebar-nav__item-badge sidebar-nav__item-badge--warning" style="display: none;">0</span>
          </a>
        </nav>

        <!-- Mode Toggle -->
        <div class="mode-toggle">
          <div class="mode-toggle__label">Editor Mode</div>
          <div class="mode-toggle__buttons">
            <button class="mode-toggle__btn mode-toggle__btn--active" id="mode-guided">Guided</button>
            <button class="mode-toggle__btn" id="mode-advanced">Advanced</button>
          </div>
        </div>
      </aside>

      <!-- Content -->
      <div class="app-content">
        <div class="split-view">
          <!-- Form Pane -->
          <div class="split-view__pane split-view__pane--form">
            <div class="split-view__header">
              <span class="split-view__title">Form Editor</span>
            </div>
            <div class="split-view__body" id="form-content">
              <div class="loading">
                <div class="loading__spinner"></div>
              </div>
            </div>
          </div>

          <!-- YAML Editor Pane -->
          <div class="split-view__pane split-view__pane--editor editor-pane">
            <div class="tabs" data-tab-group="editor">
              <button class="tab tab--active" data-tab="yaml">YAML</button>
              <button class="tab" data-tab="diff">Diff</button>
              <button class="tab" data-tab="template">Template</button>
              <button class="tab" data-tab="rendered">Rendered</button>
            </div>

            <div class="tab-content tab-content--active" data-tab-group="editor" data-tab="yaml">
              <div id="yaml-editor" style="height: 100%;"></div>
            </div>

            <div class="tab-content" data-tab-group="editor" data-tab="diff">
              <div class="diff-view" id="diff-view">
                <div class="empty-state">
                  <div class="empty-state__title">No changes</div>
                  <div class="empty-state__description">Make changes to see the diff.</div>
                </div>
              </div>
            </div>

            <div class="tab-content" data-tab-group="editor" data-tab="template">
              <div class="template-editor-pane">
                <div class="template-editor-pane__header">
                  <span id="template-name-display">No template selected</span>
                  <button class="btn btn--secondary btn--sm" id="copy-template-btn">Copy</button>
                </div>
                <div id="template-source-editor" style="height: calc(100% - 40px);"></div>
              </div>
            </div>

            <div class="tab-content" data-tab-group="editor" data-tab="rendered">
              <div class="template-editor-pane">
                <div class="template-editor-pane__header">
                  <span>Rendered Output</span>
                  <div>
                    <button class="btn btn--secondary btn--sm" id="copy-rendered-btn">Copy</button>
                    <button class="btn btn--secondary btn--sm" id="download-rendered-btn">Download</button>
                  </div>
                </div>
                <div id="rendered-output-editor" style="height: calc(100% - 40px);"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>

  <!-- Hidden file input -->
  <input type="file" id="file-input" class="file-input" accept=".yaml,.yml,.clusterfile">

  <!-- Embedded Data for Standalone Mode -->
  <script type="application/json" id="embedded-schema">
HTMLEOF

echo "${SCHEMA_JSON}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" << 'HTMLEOF'
  </script>

  <script type="application/json" id="embedded-samples">
{"samples":
HTMLEOF

echo "${SAMPLES_JSON}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" << 'HTMLEOF'
}
  </script>

  <script type="application/json" id="embedded-templates">
{"templates":
HTMLEOF

echo "${TEMPLATES_JSON}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" << HTMLEOF
}
  </script>

  <script type="application/json" id="embedded-version">
{"version": "${VERSION}", "mode": "standalone"}
  </script>

  <!-- Application Scripts -->
  <script>
HTMLEOF

echo "${JS_CONTENT}" >> "${OUTPUT_FILE}"

cat >> "${OUTPUT_FILE}" << 'HTMLEOF'
  </script>
</body>
</html>
HTMLEOF

# Get file size
FILE_SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)

echo ""
echo "Standalone HTML file created: ${OUTPUT_FILE}"
echo "File size: ${FILE_SIZE}"
echo ""
echo "To use:"
echo "  1. Open ${OUTPUT_FILE} directly in a browser"
echo "  2. Or serve via HTTP: python3 -m http.server 8080"
echo ""
echo "Features in standalone mode:"
echo "  - Schema validation (full)"
echo "  - Form editing (full)"
echo "  - YAML editor (full)"
echo "  - Diff view (full)"
echo "  - Template rendering (Nunjucks - load_file returns placeholders)"
echo "  - Load/save files (full)"
