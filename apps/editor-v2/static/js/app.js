/**
 * Clusterfile Editor v2.0 - Main Application
 *
 * Entry point that orchestrates all modules.
 */

// Module references
const State = window.EditorState;
const Validator = window.EditorValidator;
const Help = window.EditorHelp;
const CodeMirror = window.EditorCodeMirror;
const Form = window.EditorForm;

// API base URL
const API_BASE = window.location.origin;

// Application version (set by backend)
let APP_VERSION = '2.0.0';

// Flag to prevent form→editor→form sync loops
let syncingFromForm = false;

/**
 * Initialize the application
 */
async function init() {
  console.log('Initializing Clusterfile Editor v2.0');

  // Load saved state
  const saved = State.loadFromLocalStorage();
  State.state.mode = saved.mode;
  State.state.currentSection = saved.section;
  State.state.currentFilename = saved.filename;

  // Fetch schema
  try {
    const schema = await fetchSchema();
    State.state.schema = schema;
    const validatorInitialized = Validator.initValidator(schema);
    console.log('Validator initialized:', validatorInitialized);
    if (!validatorInitialized) {
      console.warn('Validator failed to initialize - validation will be skipped');
    }
  } catch (e) {
    console.error('Failed to load schema:', e);
    showToast('Failed to load schema', 'error');
  }

  // Fetch samples and templates
  try {
    const [samples, templates] = await Promise.all([
      fetchSamples(),
      fetchTemplates()
    ]);
    State.state.samples = samples;
    State.state.templates = templates;
  } catch (e) {
    console.error('Failed to load samples/templates:', e);
  }

  // Initialize UI
  initUI();

  // Restore saved document with preserved baseline and changes
  if (saved.yaml) {
    // If we have a saved baseline, use it; otherwise use current as baseline
    const baseline = saved.baseline || saved.yaml;
    State.setBaseline(baseline);
    State.updateCurrent(saved.yaml, 'restore');
    State.state.currentFilename = saved.filename;
    CodeMirror.setEditorValue(saved.yaml, false);
    updateHeader();
    renderCurrentSection();

    // Restore scroll position after render
    if (saved.scrollPosition && saved.scrollPosition.section === saved.section) {
      setTimeout(() => {
        const formContent = document.getElementById('form-content');
        if (formContent) {
          formContent.scrollTop = saved.scrollPosition.form || 0;
        }
      }, 100);
    }
  } else {
    newDocument();
  }

  // Show welcome tour on first visit
  if (!State.isTourShown()) {
    showWelcomeTour();
  }

  // Set up auto-save (every 5 seconds for better persistence)
  setInterval(() => {
    State.saveToLocalStorage();
  }, 5000);

  // Also save on page unload
  window.addEventListener('beforeunload', () => {
    State.saveToLocalStorage();
  });

  console.log('Initialization complete');
}

/**
 * Initialize UI components
 */
function initUI() {
  // Set up navigation
  setupNavigation();

  // Set up mode toggle
  setupModeToggle();

  // Set up header actions
  setupHeaderActions();

  // Initialize YAML editor
  const editorContainer = document.getElementById('yaml-editor');
  if (editorContainer) {
    CodeMirror.initYamlEditor(editorContainer);
    CodeMirror.setupEditorSync(onYamlChange);
  }

  // Initialize output editor for templates
  const outputContainer = document.getElementById('template-output-editor');
  if (outputContainer) {
    CodeMirror.initOutputEditor(outputContainer);
  }

  // Set up form change callback
  Form.setFormChangeCallback(onFormChange);

  // Set up file input
  const fileInput = document.getElementById('file-input');
  if (fileInput) {
    fileInput.addEventListener('change', handleFileLoad);
  }

  // Set up keyboard shortcuts
  setupKeyboardShortcuts();

  // Set up tab navigation
  setupTabs();

  // Populate dropdowns
  populateSamplesDropdown();
  populateTemplatesDropdown();

  // Update header
  updateHeader();

  // Initial render
  updateModeUI();
  renderCurrentSection();
}

/**
 * Set up sidebar navigation
 */
function setupNavigation() {
  const navItems = document.querySelectorAll('.sidebar-nav__item');
  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const section = item.dataset.section;
      if (section) {
        navigateToSection(section);
      }
    });

    // Set active state based on current section
    item.classList.toggle('sidebar-nav__item--active', item.dataset.section === State.state.currentSection);
  });
}

/**
 * Navigate to a section
 */
function navigateToSection(section) {
  State.state.currentSection = section;

  // Update nav active state
  document.querySelectorAll('.sidebar-nav__item').forEach(item => {
    item.classList.toggle('sidebar-nav__item--active', item.dataset.section === section);
  });

  // Render section
  renderCurrentSection();

  // Save section to localStorage immediately
  localStorage.setItem(State.STORAGE_KEYS.CURRENT_SECTION, section);
}

/**
 * Set up mode toggle
 */
function setupModeToggle() {
  const guidedBtn = document.getElementById('mode-guided');
  const advancedBtn = document.getElementById('mode-advanced');

  if (guidedBtn) {
    guidedBtn.addEventListener('click', () => setMode('guided'));
  }
  if (advancedBtn) {
    advancedBtn.addEventListener('click', () => setMode('advanced'));
  }
}

/**
 * Set editor mode
 */
function setMode(mode) {
  State.state.mode = mode;
  updateModeUI();
  localStorage.setItem(State.STORAGE_KEYS.MODE, mode);
}

/**
 * Update UI based on mode
 */
function updateModeUI() {
  const mode = State.state.mode;
  const formPane = document.querySelector('.split-view__pane--form');
  const editorPane = document.querySelector('.split-view__pane--editor');

  document.getElementById('mode-guided')?.classList.toggle('mode-toggle__btn--active', mode === 'guided');
  document.getElementById('mode-advanced')?.classList.toggle('mode-toggle__btn--active', mode === 'advanced');

  if (formPane && editorPane) {
    if (mode === 'guided') {
      formPane.style.display = 'flex';
      editorPane.style.flex = '1';
    } else {
      formPane.style.display = 'none';
      editorPane.style.flex = '1';
    }
  }

  // Refresh editor when becoming visible
  setTimeout(() => CodeMirror.refreshEditor(), 100);
}

/**
 * Set up header action buttons
 */
function setupHeaderActions() {
  // New button
  document.getElementById('btn-new')?.addEventListener('click', () => {
    if (confirm('Create new document? Unsaved changes will be lost.')) {
      newDocument();
    }
  });

  // Load button
  document.getElementById('btn-load')?.addEventListener('click', () => {
    document.getElementById('file-input')?.click();
  });

  // Save button
  document.getElementById('btn-save')?.addEventListener('click', () => {
    State.saveToLocalStorage();
    showToast('Saved to browser storage', 'success');
  });

  // Download button
  document.getElementById('btn-download')?.addEventListener('click', downloadDocument);

  // Samples dropdown
  document.getElementById('btn-samples')?.addEventListener('click', (e) => {
    const dropdown = e.target.closest('.dropdown');
    dropdown?.classList.toggle('dropdown--open');
  });

  // Close dropdowns on outside click
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.dropdown')) {
      document.querySelectorAll('.dropdown--open').forEach(d => d.classList.remove('dropdown--open'));
    }
  });
}

/**
 * Set up keyboard shortcuts
 */
function setupKeyboardShortcuts() {
  document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + S to save
    if ((e.ctrlKey || e.metaKey) && e.key === 's') {
      e.preventDefault();
      State.saveToLocalStorage();
      showToast('Saved', 'success');
    }

    // Ctrl/Cmd + O to load
    if ((e.ctrlKey || e.metaKey) && e.key === 'o') {
      e.preventDefault();
      document.getElementById('file-input')?.click();
    }
  });
}

/**
 * Set up tab navigation
 */
function setupTabs() {
  const tabs = document.querySelectorAll('.tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const tabGroup = tab.closest('.tabs')?.dataset.tabGroup;
      const tabId = tab.dataset.tab;

      if (tabGroup && tabId) {
        // Update active tab
        document.querySelectorAll(`.tabs[data-tab-group="${tabGroup}"] .tab`).forEach(t => {
          t.classList.toggle('tab--active', t.dataset.tab === tabId);
        });

        // Update active content
        document.querySelectorAll(`.tab-content[data-tab-group="${tabGroup}"]`).forEach(c => {
          c.classList.toggle('tab-content--active', c.dataset.tab === tabId);
        });

        // Refresh editor if needed
        if (tabId === 'yaml' || tabId === 'output') {
          setTimeout(() => CodeMirror.refreshEditor(), 100);
        }

        // Update diff view when switching to diff tab
        if (tabId === 'diff') {
          updateDiffView();
        }
      }
    });
  });
}

/**
 * Update the diff view
 */
function updateDiffView() {
  const diffContainer = document.getElementById('diff-view');
  if (!diffContainer) return;

  const baseline = State.state.baselineYamlText;
  const current = State.state.currentYamlText;

  if (baseline === current) {
    diffContainer.innerHTML = `
      <div class="empty-state">
        <div class="empty-state__icon">✓</div>
        <div class="empty-state__title">No changes</div>
        <div class="empty-state__description">Your document matches the baseline.</div>
      </div>
    `;
    return;
  }

  // Use diff library if available
  if (window.Diff) {
    const diff = Diff.createTwoFilesPatch(
      'baseline',
      'current',
      baseline,
      current,
      'Original',
      'Modified'
    );

    const lines = diff.split('\n');
    const html = lines.map(line => {
      if (line.startsWith('+') && !line.startsWith('+++')) {
        return `<div class="diff-line diff-line--add">${Help.escapeHtml(line)}</div>`;
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        return `<div class="diff-line diff-line--remove">${Help.escapeHtml(line)}</div>`;
      } else if (line.startsWith('@@')) {
        return `<div class="diff-line diff-line--header">${Help.escapeHtml(line)}</div>`;
      } else {
        return `<div class="diff-line">${Help.escapeHtml(line)}</div>`;
      }
    }).join('');

    diffContainer.innerHTML = html;
  } else {
    // Fallback: simple line-by-line comparison
    const baselineLines = baseline.split('\n');
    const currentLines = current.split('\n');
    let html = '';

    const maxLen = Math.max(baselineLines.length, currentLines.length);
    for (let i = 0; i < maxLen; i++) {
      const baseLine = baselineLines[i] || '';
      const currLine = currentLines[i] || '';

      if (baseLine !== currLine) {
        if (baseLine) {
          html += `<div class="diff-line diff-line--remove">- ${Help.escapeHtml(baseLine)}</div>`;
        }
        if (currLine) {
          html += `<div class="diff-line diff-line--add">+ ${Help.escapeHtml(currLine)}</div>`;
        }
      } else {
        html += `<div class="diff-line">  ${Help.escapeHtml(baseLine)}</div>`;
      }
    }

    diffContainer.innerHTML = html;
  }
}

/**
 * Render the current section
 */
function renderCurrentSection() {
  const section = State.state.currentSection;
  const container = document.getElementById('form-content');

  if (!container) return;

  if (section === 'templates') {
    renderTemplatesSection(container);
  } else if (section === 'changes') {
    renderChangesSection(container);
  } else if (section === 'validation') {
    renderValidationSection(container);
  } else {
    Form.renderSection(section, container);
  }

  // Update validation count
  updateValidationBadge();
  updateChangesBadge();
}

/**
 * Render templates section
 */
function renderTemplatesSection(container) {
  container.innerHTML = `
    <div class="template-panel">
      <div class="form-section">
        <h2 class="form-section__title">Template Rendering</h2>

        <div class="form-group template-select">
          <label class="form-label">Template</label>
          <select class="form-select" id="template-select">
            <option value="">-- Select Template --</option>
            ${State.state.templates.map(t => `
              <option value="${Help.escapeHtml(t.name)}">${Help.escapeHtml(t.name)}</option>
            `).join('')}
          </select>
          <div class="form-description" id="template-description"></div>
        </div>

        <div class="form-group template-params">
          <label class="form-label">Parameter Overrides</label>
          <div id="template-params-list"></div>
          <button class="btn btn--secondary btn--sm" id="add-param-btn">+ Add Parameter</button>
        </div>

        <div class="form-group">
          <button class="btn btn--primary" id="render-btn">Render Template</button>
          <button class="btn btn--secondary" id="view-template-btn">View Template Source</button>
        </div>

        <div class="template-output" id="template-output-container" style="display: none;">
          <div class="template-output__header">
            <span>Output</span>
            <div class="split-view__actions">
              <button class="btn btn--secondary btn--sm" id="copy-output-btn">Copy</button>
              <button class="btn btn--secondary btn--sm" id="download-output-btn">Download</button>
            </div>
          </div>
          <div class="template-output__body" id="template-output-editor"></div>
        </div>
      </div>
    </div>
  `;

  // Set up event listeners
  const templateSelect = document.getElementById('template-select');
  const paramsContainer = document.getElementById('template-params-list');

  templateSelect?.addEventListener('change', () => {
    const template = State.state.templates.find(t => t.name === templateSelect.value);
    document.getElementById('template-description').textContent = template?.description || '';
  });

  document.getElementById('add-param-btn')?.addEventListener('click', () => {
    addParamInput(paramsContainer);
  });

  document.getElementById('render-btn')?.addEventListener('click', renderTemplate);
  document.getElementById('view-template-btn')?.addEventListener('click', viewTemplateSource);
  document.getElementById('copy-output-btn')?.addEventListener('click', copyOutput);
  document.getElementById('download-output-btn')?.addEventListener('click', downloadOutput);

  // Re-initialize output editor
  const outputContainer = document.getElementById('template-output-editor');
  if (outputContainer) {
    outputContainer.innerHTML = '';
    CodeMirror.initOutputEditor(outputContainer);
  }
}

/**
 * Add a parameter input
 */
function addParamInput(container) {
  const param = document.createElement('div');
  param.className = 'template-param';
  param.innerHTML = `
    <input type="text" class="form-input" placeholder="$.path.to.field" style="flex: 1;">
    <span>=</span>
    <input type="text" class="form-input" placeholder="value" style="flex: 1;">
    <span class="array-field__item-remove" title="Remove">×</span>
  `;

  param.querySelector('.array-field__item-remove').addEventListener('click', () => {
    param.remove();
  });

  container.appendChild(param);
}

/**
 * Render template
 */
async function renderTemplate() {
  const templateName = document.getElementById('template-select')?.value;
  if (!templateName) {
    showToast('Please select a template', 'warning');
    return;
  }

  // Collect params
  const params = [];
  document.querySelectorAll('.template-param').forEach(param => {
    const inputs = param.querySelectorAll('input');
    const path = inputs[0]?.value;
    const value = inputs[1]?.value;
    if (path && value) {
      params.push(`${path}=${value}`);
    }
  });

  try {
    const response = await fetch(`${API_BASE}/api/render`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        yaml_text: State.state.currentYamlText,
        template_name: templateName,
        params
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Render failed');
    }

    const result = await response.json();

    // Show output
    document.getElementById('template-output-container').style.display = 'block';
    CodeMirror.setOutputValue(result.output);

    if (result.warnings?.length > 0) {
      showToast(`Rendered with ${result.warnings.length} warning(s)`, 'warning');
    } else {
      showToast('Template rendered successfully', 'success');
    }
  } catch (e) {
    showToast(`Render error: ${e.message}`, 'error');
  }
}

/**
 * View template source
 */
async function viewTemplateSource() {
  const templateName = document.getElementById('template-select')?.value;
  if (!templateName) {
    showToast('Please select a template', 'warning');
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/api/templates/${templateName}`);
    if (!response.ok) throw new Error('Failed to load template');

    const result = await response.json();
    document.getElementById('template-output-container').style.display = 'block';
    CodeMirror.setOutputValue(result.content);
  } catch (e) {
    showToast(`Error: ${e.message}`, 'error');
  }
}

/**
 * Copy output to clipboard
 */
async function copyOutput() {
  const output = CodeMirror.getOutputValue();
  try {
    await navigator.clipboard.writeText(output);
    showToast('Copied to clipboard', 'success');
  } catch (e) {
    showToast('Failed to copy', 'error');
  }
}

/**
 * Download output
 */
function downloadOutput() {
  const output = CodeMirror.getOutputValue();
  const templateName = document.getElementById('template-select')?.value || 'output';
  const filename = templateName.replace('.tpl', '').replace('.tmpl', '');
  downloadFile(output, filename);
}

/**
 * Render changes section
 */
function renderChangesSection(container) {
  const changes = State.getChanges();

  if (changes.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state__icon">✓</div>
        <div class="empty-state__title">No changes</div>
        <div class="empty-state__description">Your document matches the baseline.</div>
      </div>
    `;
    return;
  }

  container.innerHTML = `
    <div class="changes-list">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3 style="margin: 0;">${changes.length} Change${changes.length !== 1 ? 's' : ''}</h3>
        <button class="btn btn--danger btn--sm" id="revert-all-btn">Revert All</button>
      </div>
      ${changes.map(c => `
        <div class="change-item">
          <span class="change-item__path">${Help.escapeHtml(c.path)}</span>
          <span class="change-item__value" title="${Help.escapeHtml(JSON.stringify(c.value))}">${Help.escapeHtml(JSON.stringify(c.value).substring(0, 50))}</span>
          <span class="change-item__time">${formatTime(c.timestamp)}</span>
          <button class="btn btn--link btn--sm" data-path="${Help.escapeHtml(c.path)}">Revert</button>
        </div>
      `).join('')}
    </div>
  `;

  // Set up revert handlers
  document.getElementById('revert-all-btn')?.addEventListener('click', () => {
    if (confirm('Revert all changes?')) {
      State.revertAll();
      syncEditorFromState();
      renderCurrentSection();
      showToast('All changes reverted', 'success');
    }
  });

  container.querySelectorAll('[data-path]').forEach(btn => {
    btn.addEventListener('click', () => {
      const path = btn.dataset.path;
      State.revertPath(path);
      syncEditorFromState();
      renderCurrentSection();
    });
  });
}

/**
 * Render validation section
 */
function renderValidationSection(container) {
  const result = Validator.validateDocument(State.state.currentObject);
  State.state.validationErrors = result.errors;

  if (result.valid) {
    container.innerHTML = `
      <div class="empty-state">
        <div class="empty-state__icon" style="color: var(--pf-global--success-color--100);">✓</div>
        <div class="empty-state__title">Valid Document</div>
        <div class="empty-state__description">Your clusterfile passes all schema validations.</div>
      </div>
    `;
    return;
  }

  container.innerHTML = `
    <div class="validation-panel">
      <h3 style="margin: 0 0 16px 0;">${result.errors.length} Validation Error${result.errors.length !== 1 ? 's' : ''}</h3>
      ${result.errors.map(e => `
        <div class="validation-item">
          <span class="validation-item__icon validation-item__icon--error">⚠</span>
          <div class="validation-item__content">
            <span class="validation-item__path" data-path="${Help.escapeHtml(e.path)}">${Help.escapeHtml(e.path || '(root)')}</span>
            <div class="validation-item__message">${Help.escapeHtml(e.message)}</div>
          </div>
        </div>
      `).join('')}
    </div>
  `;

  // Set up path click handlers
  container.querySelectorAll('.validation-item__path').forEach(pathEl => {
    pathEl.addEventListener('click', () => {
      const path = pathEl.dataset.path;
      if (path) {
        // Navigate to the field
        const parts = State.parsePath(path);
        if (parts.length > 0) {
          const section = parts[0];
          navigateToSection(section);
        }
        // Also try to go to line in editor
        CodeMirror.goToPath(path);
      }
    });
  });
}

/**
 * Handle YAML editor changes
 */
function onYamlChange(yamlText) {
  // Skip if this change came from form sync (prevents loop)
  if (syncingFromForm) {
    return;
  }

  // Validate YAML syntax
  try {
    jsyaml.load(yamlText);
  } catch (e) {
    // Invalid YAML - don't sync
    return;
  }

  State.updateCurrent(yamlText, 'editor');

  // Re-render form if in guided mode (only for direct editor changes)
  if (State.state.mode === 'guided') {
    renderCurrentSection();
  }

  updateValidationBadge();
  updateChangesBadge();
}

/**
 * Handle form changes
 */
function onFormChange() {
  // Set flag to prevent editor change from triggering form re-render
  syncingFromForm = true;

  // Sync to YAML
  const yaml = State.toYaml();
  State.state.currentYamlText = yaml;
  CodeMirror.setEditorValue(yaml, true);

  // Clear flag after a short delay (after editor change event fires)
  setTimeout(() => {
    syncingFromForm = false;
  }, 50);

  updateValidationBadge();
  updateChangesBadge();

  // Note: Don't re-render the section here - it would destroy active form inputs
  // Change indicators are updated inline by updateFieldValue in form.js
}

/**
 * Sync editor from state
 */
function syncEditorFromState() {
  const yaml = State.toYaml();
  State.state.currentYamlText = yaml;
  CodeMirror.setEditorValue(yaml, false);
}

/**
 * Update validation badge
 */
function updateValidationBadge() {
  const result = Validator.validateDocument(State.state.currentObject);
  State.state.validationErrors = result.errors;

  const badge = document.querySelector('[data-section="validation"] .sidebar-nav__item-badge');
  if (badge) {
    badge.textContent = result.errors.length;
    badge.style.display = result.errors.length > 0 ? 'inline' : 'none';
  }
}

/**
 * Update changes badge
 */
function updateChangesBadge() {
  const changes = State.getChanges();
  const badge = document.querySelector('[data-section="changes"] .sidebar-nav__item-badge');
  if (badge) {
    badge.textContent = changes.length;
    badge.style.display = changes.length > 0 ? 'inline' : 'none';
  }
}

/**
 * Update header
 */
function updateHeader() {
  const filenameEl = document.querySelector('.app-header__filename');
  if (filenameEl) {
    filenameEl.textContent = State.state.currentFilename;
  }
}

/**
 * Load a document
 */
function loadDocument(yamlText, filename = 'untitled.clusterfile', setAsBaseline = true) {
  State.state.currentFilename = filename;

  if (setAsBaseline) {
    State.setBaseline(yamlText);
  }
  State.updateCurrent(yamlText, 'load');

  CodeMirror.setEditorValue(yamlText, false);
  updateHeader();
  renderCurrentSection();

  // Update diff view if currently visible
  updateDiffView();

  // Update validation
  updateValidationBadge();
}

/**
 * Create new document
 */
function newDocument() {
  const emptyDoc = `# Clusterfile
account: {}
cluster: {}
network:
  domain: ""
hosts: {}
`;
  loadDocument(emptyDoc, 'untitled.clusterfile', true);
}

/**
 * Handle file load
 */
function handleFileLoad(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = (e) => {
    const content = e.target?.result;
    if (typeof content === 'string') {
      loadDocument(content, file.name, true);
      showToast(`Loaded ${file.name}`, 'success');
    }
  };
  reader.onerror = () => {
    showToast('Failed to read file', 'error');
  };
  reader.readAsText(file);

  // Reset input
  event.target.value = '';
}

/**
 * Download document
 */
function downloadDocument() {
  const yaml = State.toYaml();
  const filename = State.state.currentFilename || 'clusterfile.yaml';
  downloadFile(yaml, filename);
  showToast('Downloaded', 'success');
}

/**
 * Download a file
 */
function downloadFile(content, filename) {
  const blob = new Blob([content], { type: 'text/yaml' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

/**
 * Populate samples dropdown
 */
function populateSamplesDropdown() {
  const menu = document.getElementById('samples-menu');
  if (!menu) return;

  menu.innerHTML = State.state.samples.map(s => `
    <button class="dropdown__item" data-filename="${Help.escapeHtml(s.filename)}">
      ${Help.escapeHtml(s.name)}
    </button>
  `).join('');

  menu.querySelectorAll('.dropdown__item').forEach(item => {
    item.addEventListener('click', async () => {
      const filename = item.dataset.filename;
      try {
        const response = await fetch(`${API_BASE}/api/samples/${filename}`);
        if (!response.ok) throw new Error('Failed to load sample');
        const result = await response.json();
        loadDocument(result.content, filename, true);
        showToast(`Loaded sample: ${filename}`, 'success');
      } catch (e) {
        showToast(`Error: ${e.message}`, 'error');
      }

      // Close dropdown
      item.closest('.dropdown')?.classList.remove('dropdown--open');
    });
  });
}

/**
 * Populate templates dropdown
 */
function populateTemplatesDropdown() {
  // Templates are populated in renderTemplatesSection
}

/**
 * Show welcome tour modal
 */
function showWelcomeTour() {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `
    <div class="modal">
      <div class="modal__header">
        <h2 class="modal__title">Welcome to Clusterfile Editor</h2>
        <span class="modal__close">×</span>
      </div>
      <div class="modal__body">
        <div class="tour-step">
          <span class="tour-step__number">1</span>
          <div class="tour-step__title">Choose Your Mode</div>
          <div class="tour-step__description">
            Use <strong>Guided</strong> mode for form-based editing, or <strong>Advanced</strong> for direct YAML editing.
          </div>
        </div>
        <div class="tour-step">
          <span class="tour-step__number">2</span>
          <div class="tour-step__title">Navigate Sections</div>
          <div class="tour-step__description">
            Use the sidebar to navigate between Account, Cluster, Network, Hosts, and Plugins sections.
          </div>
        </div>
        <div class="tour-step">
          <span class="tour-step__number">3</span>
          <div class="tour-step__title">Get Help</div>
          <div class="tour-step__description">
            Click the <strong>?</strong> icon next to any field to see documentation and helpful links.
          </div>
        </div>
        <div class="tour-step">
          <span class="tour-step__number">4</span>
          <div class="tour-step__title">Render Templates</div>
          <div class="tour-step__description">
            Go to <strong>Templates</strong> to render install-config.yaml and other manifests.
          </div>
        </div>
      </div>
      <div class="modal__footer">
        <label style="flex: 1; display: flex; align-items: center; gap: 8px;">
          <input type="checkbox" id="tour-dont-show">
          Don't show again
        </label>
        <button class="btn btn--primary" id="tour-close">Get Started</button>
      </div>
    </div>
  `;

  document.body.appendChild(overlay);

  const closeModal = () => {
    if (document.getElementById('tour-dont-show')?.checked) {
      State.setTourShown();
    }
    overlay.remove();
  };

  overlay.querySelector('.modal__close').addEventListener('click', closeModal);
  overlay.querySelector('#tour-close').addEventListener('click', closeModal);
  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closeModal();
  });
}

/**
 * Show toast notification
 */
function showToast(message, type = 'info') {
  let container = document.querySelector('.toast-container');
  if (!container) {
    container = document.createElement('div');
    container.className = 'toast-container';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = `toast toast--${type}`;
  toast.innerHTML = `
    <span>${Help.escapeHtml(message)}</span>
    <span class="toast__close">×</span>
  `;

  toast.querySelector('.toast__close').addEventListener('click', () => {
    toast.remove();
  });

  container.appendChild(toast);

  // Auto-remove after 5 seconds
  setTimeout(() => {
    toast.remove();
  }, 5000);
}

/**
 * Format timestamp
 */
function formatTime(timestamp) {
  const date = new Date(timestamp);
  return date.toLocaleTimeString();
}

/**
 * Fetch schema from API
 */
async function fetchSchema() {
  const response = await fetch(`${API_BASE}/api/schema`);
  if (!response.ok) throw new Error('Failed to fetch schema');
  return response.json();
}

/**
 * Fetch samples from API
 */
async function fetchSamples() {
  const response = await fetch(`${API_BASE}/api/samples`);
  if (!response.ok) throw new Error('Failed to fetch samples');
  const data = await response.json();
  return data.samples || [];
}

/**
 * Fetch templates from API
 */
async function fetchTemplates() {
  const response = await fetch(`${API_BASE}/api/templates`);
  if (!response.ok) throw new Error('Failed to fetch templates');
  const data = await response.json();
  return data.templates || [];
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', init);

// Export for debugging
window.ClusterfileEditor = {
  State,
  Validator,
  Help,
  CodeMirror,
  Form,
  init,
  loadDocument,
  newDocument,
  showToast
};
