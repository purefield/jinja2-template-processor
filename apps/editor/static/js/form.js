/**
 * Clusterfile Editor v2.0 - Form Renderer Module
 *
 * Schema-driven form generation with two-way sync.
 */
(function() {
'use strict';

// Get references from other modules
const State = window.EditorState || {};
const Help = window.EditorHelp || {};
const Validator = window.EditorValidator || {};

let formSyncTimeout = null;
let onFormChange = null;
const FORM_SYNC_DELAY = 300;

/**
 * Resolve $ref in schema
 * @param {object} schema - Schema that might contain $ref
 * @param {object} rootSchema - Root schema containing $defs
 * @returns {object} - Resolved schema with $ref replaced
 */
function resolveRef(schema, rootSchema) {
  if (!schema) return schema;

  // If schema has $ref, resolve it
  if (schema.$ref) {
    const refPath = schema.$ref;
    // Handle local refs like "#/$defs/ipv4"
    if (refPath.startsWith('#/') && rootSchema) {
      const parts = refPath.substring(2).split('/');
      let resolved = rootSchema;
      for (const part of parts) {
        resolved = resolved?.[part];
        if (!resolved) {
          console.warn(`[resolveRef] Failed to resolve path part "${part}" in $ref "${refPath}"`);
          break;
        }
      }
      if (resolved) {
        // Merge the resolved ref with any other properties (like title, description)
        const { $ref, ...rest } = schema;
        return { ...resolved, ...rest };
      }
    } else if (!rootSchema) {
      console.warn(`[resolveRef] No rootSchema provided to resolve $ref "${refPath}"`);
    }
  }

  return schema;
}

/**
 * Get the effective type of a schema (resolving $ref if needed)
 */
function getSchemaType(schema, rootSchema) {
  const resolved = resolveRef(schema, rootSchema);
  return resolved?.type;
}

/**
 * Set form change callback
 */
function setFormChangeCallback(callback) {
  onFormChange = callback;
}

/**
 * Trigger form change with debounce
 */
function triggerFormChange() {
  clearTimeout(formSyncTimeout);
  formSyncTimeout = setTimeout(() => {
    if (onFormChange) {
      onFormChange();
    }
  }, FORM_SYNC_DELAY);
}

/**
 * Render a section of the form
 */
function renderSection(sectionName, container) {
  if (!State.state?.schema?.properties?.[sectionName]) {
    container.innerHTML = `<div class="empty-state">
      <div class="empty-state__title">Schema not loaded</div>
      <div class="empty-state__description">Unable to render form without schema.</div>
    </div>`;
    return;
  }

  const sectionSchema = State.state.schema.properties[sectionName];
  container.innerHTML = '';

  const section = document.createElement('div');
  section.className = 'form-section';

  const title = document.createElement('h2');
  title.className = 'form-section__title';
  title.textContent = sectionSchema.title || sectionName;
  section.appendChild(title);

  if (sectionName === 'hosts') {
    renderHostsSection(section, sectionSchema);
  } else if (sectionName === 'plugins') {
    renderPluginsSection(section, sectionSchema);
  } else {
    renderObjectFields(section, sectionSchema, sectionName, State.state.currentObject?.[sectionName] || {});
  }

  container.appendChild(section);
}

/**
 * Map platform to plugin name
 * Some platforms map to the same plugin, others have no plugin
 */
const PLATFORM_TO_PLUGIN = {
  'vsphere': 'vsphere',
  'aws': 'aws',
  'azure': 'azure',
  'gcp': 'gcp',
  'openstack': 'openstack',
  'ibmcloud': 'ibmcloud',
  'nutanix': 'nutanix',
  // These platforms don't have specific plugins
  'baremetal': null,
  'none': null
};

/**
 * Render plugins section - only shows the plugin matching the selected platform
 */
function renderPluginsSection(container, schema) {
  const platform = State.state.currentObject?.cluster?.platform;
  const pluginName = PLATFORM_TO_PLUGIN[platform];

  // No platform selected
  if (!platform) {
    const notice = document.createElement('div');
    notice.className = 'empty-state';
    notice.innerHTML = `
      <div class="empty-state__icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" width="48" height="48">
          <circle cx="12" cy="12" r="10"/>
          <line x1="12" y1="8" x2="12" y2="12"/>
          <line x1="12" y1="16" x2="12.01" y2="16"/>
        </svg>
      </div>
      <div class="empty-state__title">No platform selected</div>
      <div class="empty-state__description">Select a platform in the <strong>Cluster</strong> section to configure platform-specific settings.</div>
    `;
    container.appendChild(notice);
    return;
  }

  // Platform doesn't have a plugin (baremetal, none)
  if (pluginName === null) {
    const notice = document.createElement('div');
    notice.className = 'empty-state';
    notice.innerHTML = `
      <div class="empty-state__icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" width="48" height="48">
          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
          <polyline points="22,4 12,14.01 9,11.01"/>
        </svg>
      </div>
      <div class="empty-state__title">No plugin required</div>
      <div class="empty-state__description">The <strong>${Help.escapeHtml(platform)}</strong> platform does not require additional plugin configuration.</div>
    `;
    container.appendChild(notice);
    return;
  }

  // Check if plugin schema exists
  const pluginSchema = schema.properties?.[pluginName];
  if (!pluginSchema) {
    const notice = document.createElement('div');
    notice.className = 'empty-state';
    notice.innerHTML = `
      <div class="empty-state__icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" width="48" height="48">
          <circle cx="12" cy="12" r="10"/>
          <line x1="15" y1="9" x2="9" y2="15"/>
          <line x1="9" y1="9" x2="15" y2="15"/>
        </svg>
      </div>
      <div class="empty-state__title">Plugin not available</div>
      <div class="empty-state__description">No schema defined for the <strong>${Help.escapeHtml(pluginName)}</strong> plugin.</div>
    `;
    container.appendChild(notice);
    return;
  }

  // Show platform indicator
  const platformBadge = document.createElement('div');
  platformBadge.className = 'plugin-platform-badge';
  platformBadge.innerHTML = `
    <span class="plugin-platform-badge__label">Platform:</span>
    <span class="plugin-platform-badge__value">${Help.escapeHtml(platform)}</span>
  `;
  platformBadge.style.marginBottom = '16px';
  platformBadge.style.padding = '8px 12px';
  platformBadge.style.background = 'var(--pf-global--BackgroundColor--200)';
  platformBadge.style.borderRadius = '4px';
  platformBadge.style.display = 'inline-block';
  platformBadge.style.fontSize = '0.875rem';
  container.appendChild(platformBadge);

  // Render plugin title as subsection
  const pluginTitle = document.createElement('h3');
  pluginTitle.className = 'form-section__subtitle';
  pluginTitle.textContent = pluginSchema.title || pluginName;
  pluginTitle.style.marginTop = '16px';
  pluginTitle.style.marginBottom = '12px';
  pluginTitle.style.color = 'var(--pf-global--Color--100)';
  pluginTitle.style.fontSize = '1rem';
  pluginTitle.style.fontWeight = '600';
  container.appendChild(pluginTitle);

  // Render plugin fields
  const pluginData = State.state.currentObject?.plugins?.[pluginName] || {};
  const path = `plugins.${pluginName}`;
  renderObjectFields(container, pluginSchema, path, pluginData);
}

/**
 * Render hosts section with pattern properties
 */
function renderHostsSection(container, schema) {
  const hostsData = State.state.currentObject?.hosts || {};
  const hostNames = Object.keys(hostsData);

  // Add host button
  const addBtn = document.createElement('button');
  addBtn.className = 'btn btn--primary btn--sm';
  addBtn.innerHTML = '+ Add Host';
  addBtn.style.marginBottom = '16px';
  addBtn.addEventListener('click', () => showAddHostModal());
  container.appendChild(addBtn);

  if (hostNames.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'empty-state';
    empty.innerHTML = `
      <div class="empty-state__icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" width="48" height="48">
          <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
          <line x1="8" y1="21" x2="16" y2="21"/>
          <line x1="12" y1="17" x2="12" y2="21"/>
        </svg>
      </div>
      <div class="empty-state__title">No hosts configured</div>
      <div class="empty-state__description">Add hosts to configure your cluster nodes.</div>
    `;
    container.appendChild(empty);
    return;
  }

  const cards = document.createElement('div');
  cards.className = 'host-cards';

  // Get host schema from patternProperties
  const hostSchema = getHostSchema(schema);

  for (const hostname of hostNames) {
    const hostData = hostsData[hostname] || {};
    const card = renderHostCard(hostname, hostData, hostSchema);
    cards.appendChild(card);
  }

  container.appendChild(cards);
}

/**
 * Get host schema from patternProperties
 */
function getHostSchema(hostsSchema) {
  if (hostsSchema.patternProperties) {
    const patterns = Object.keys(hostsSchema.patternProperties);
    if (patterns.length > 0) {
      return hostsSchema.patternProperties[patterns[0]];
    }
  }
  return { type: 'object', properties: {} };
}

/**
 * Render a host card
 */
function renderHostCard(hostname, hostData, hostSchema) {
  const card = document.createElement('div');
  card.className = 'host-card';
  card.dataset.hostname = hostname;

  const role = hostData.role || 'worker';
  const roleClass = `host-card__role--${role}`;

  card.innerHTML = `
    <div class="host-card__header">
      <span class="host-card__toggle">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><polyline points="6,9 12,15 18,9"/></svg>
      </span>
      <span class="host-card__hostname">${Help.escapeHtml(hostname)}</span>
      <span class="host-card__role ${roleClass}">${Help.escapeHtml(role)}</span>
      <div class="host-card__actions">
        <button class="btn btn--secondary btn--icon btn--sm" title="Duplicate" data-action="duplicate">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="14" height="14"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
        </button>
        <button class="btn btn--secondary btn--icon btn--sm" title="Rename" data-action="rename">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="14" height="14"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
        </button>
        <button class="btn btn--danger btn--icon btn--sm" title="Remove" data-action="remove">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="14" height="14"><polyline points="3,6 5,6 21,6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
        </button>
      </div>
    </div>
    <div class="host-card__body"></div>
  `;

  // Toggle collapse
  const header = card.querySelector('.host-card__header');
  header.addEventListener('click', (e) => {
    if (e.target.closest('.host-card__actions')) return;
    card.classList.toggle('host-card--collapsed');
  });

  // Action buttons
  card.querySelector('[data-action="duplicate"]').addEventListener('click', (e) => {
    e.stopPropagation();
    duplicateHost(hostname);
  });

  card.querySelector('[data-action="rename"]').addEventListener('click', (e) => {
    e.stopPropagation();
    renameHost(hostname);
  });

  card.querySelector('[data-action="remove"]').addEventListener('click', (e) => {
    e.stopPropagation();
    removeHost(hostname);
  });

  // Render host fields
  const body = card.querySelector('.host-card__body');
  const path = `hosts["${hostname}"]`;
  renderObjectFields(body, hostSchema, path, hostData);

  return card;
}

/**
 * Render object fields recursively
 */
function renderObjectFields(container, schema, basePath, data) {
  if (!schema.properties) return;

  for (const [key, fieldSchema] of Object.entries(schema.properties)) {
    const path = basePath ? `${basePath}.${key}` : key;
    const value = data?.[key];

    const fieldElement = renderField(path, key, fieldSchema, value);
    if (fieldElement) {
      container.appendChild(fieldElement);
    }
  }
}

/**
 * Render a single field based on schema type
 */
function renderField(path, key, schema, value) {
  // Handle anyOf/oneOf
  if (schema.anyOf || schema.oneOf) {
    return renderUnionField(path, key, schema, value);
  }

  const type = schema.type;

  switch (type) {
    case 'string':
      return renderStringField(path, key, schema, value);
    case 'integer':
    case 'number':
      return renderNumberField(path, key, schema, value);
    case 'boolean':
      return renderBooleanField(path, key, schema, value);
    case 'array':
      return renderArrayField(path, key, schema, value);
    case 'object':
      return renderObjectField(path, key, schema, value);
    default:
      return renderStringField(path, key, schema, value);
  }
}

/**
 * Render a string input field
 */
function renderStringField(path, key, schema, value) {
  const group = createFormGroup(path, key, schema);

  if (schema.enum) {
    // Use select for enum
    return renderEnumField(path, key, schema, value);
  }

  // Handle x-is-file fields with special styling
  if (schema['x-is-file']) {
    const fileContainer = document.createElement('div');
    fileContainer.className = 'file-path-input';
    fileContainer.style.display = 'flex';
    fileContainer.style.alignItems = 'center';
    fileContainer.style.gap = '8px';

    // File icon (modern SVG)
    const fileIcon = document.createElement('span');
    fileIcon.className = 'file-path-icon';
    fileIcon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="18" height="18"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>';
    fileIcon.title = 'File path - will be read when processing locally';
    fileContainer.appendChild(fileIcon);

    const input = document.createElement('input');
    input.type = 'text';
    input.className = 'form-input form-input--file-path';
    input.id = `field-${path.replace(/[.\[\]"]/g, '-')}`;
    // Show actual value, not redacted - redaction only happens in localStorage
    input.value = value || '';
    input.placeholder = '/path/to/file';

    input.addEventListener('input', () => {
      updateFieldValue(path, input.value, schema);
    });

    fileContainer.appendChild(input);

    // Info tooltip (modern SVG)
    const infoIcon = document.createElement('span');
    infoIcon.className = 'file-path-info';
    infoIcon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="16" height="16"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';
    infoIcon.title = 'This path will be read by the template processor when run locally. The file contents are never stored in the browser.';
    infoIcon.style.cursor = 'help';
    fileContainer.appendChild(infoIcon);

    group.appendChild(fileContainer);
    addFieldDescription(group, schema);
    return group;
  }

  const input = document.createElement('input');
  input.type = 'text';
  input.className = 'form-input';
  input.id = `field-${path.replace(/[.\[\]"]/g, '-')}`;
  input.value = value || '';
  input.placeholder = schema.default !== undefined ? String(schema.default) : '';

  input.addEventListener('input', () => {
    updateFieldValue(path, input.value, schema);
  });

  group.appendChild(input);
  addFieldDescription(group, schema);
  return group;
}

/**
 * Render an enum select field with optional "Other" input
 */
function renderEnumField(path, key, schema, value, allowCustom = true) {
  const group = createFormGroup(path, key, schema);

  // Check if current value is a custom value (not in enum)
  const isCustomValue = value && !schema.enum.includes(value);

  // Container for select + optional input
  const container = document.createElement('div');
  container.className = 'enum-field-container';
  container.style.display = 'flex';
  container.style.gap = '8px';
  container.style.alignItems = 'center';

  const select = document.createElement('select');
  select.className = 'form-select';
  select.id = `field-${path.replace(/[.\[\]"]/g, '-')}`;
  select.style.flex = allowCustom ? '0 0 auto' : '1';

  // Add empty option
  const emptyOpt = document.createElement('option');
  emptyOpt.value = '';
  emptyOpt.textContent = '-- Select --';
  select.appendChild(emptyOpt);

  for (const opt of schema.enum) {
    const option = document.createElement('option');
    option.value = opt;
    option.textContent = opt;
    if (opt === value) {
      option.selected = true;
    }
    select.appendChild(option);
  }

  // Add "Other" option if custom values allowed
  if (allowCustom) {
    const otherOpt = document.createElement('option');
    otherOpt.value = '__other__';
    otherOpt.textContent = 'Other...';
    if (isCustomValue) {
      otherOpt.selected = true;
    }
    select.appendChild(otherOpt);
  }

  container.appendChild(select);

  // Custom input field (shown when "Other" is selected)
  const customInput = document.createElement('input');
  customInput.type = 'text';
  customInput.className = 'form-input';
  customInput.placeholder = 'Enter custom value';
  customInput.style.flex = '1';
  customInput.style.display = isCustomValue ? 'block' : 'none';
  customInput.value = isCustomValue ? value : '';

  if (allowCustom) {
    container.appendChild(customInput);
  }

  select.addEventListener('change', () => {
    if (select.value === '__other__') {
      customInput.style.display = 'block';
      customInput.focus();
      // Clear the value until user types something
      if (!customInput.value) {
        updateFieldValue(path, '', schema);
      }
    } else {
      customInput.style.display = 'none';
      customInput.value = '';
      updateFieldValue(path, select.value, schema);
    }
  });

  customInput.addEventListener('input', () => {
    updateFieldValue(path, customInput.value, schema);
  });

  group.appendChild(container);
  addFieldDescription(group, schema);
  return group;
}

/**
 * Render a number input field
 */
function renderNumberField(path, key, schema, value) {
  const group = createFormGroup(path, key, schema);
  const input = document.createElement('input');
  input.type = 'number';
  input.className = 'form-input form-input--number';
  input.id = `field-${path.replace(/[.\[\]"]/g, '-')}`;
  input.value = value !== undefined ? value : '';

  if (schema.minimum !== undefined) {
    input.min = schema.minimum;
  }
  if (schema.maximum !== undefined) {
    input.max = schema.maximum;
  }
  if (schema.type === 'integer') {
    input.step = '1';
  }

  input.addEventListener('input', () => {
    const numVal = schema.type === 'integer' ? parseInt(input.value, 10) : parseFloat(input.value);
    updateFieldValue(path, isNaN(numVal) ? undefined : numVal, schema);
  });

  group.appendChild(input);
  addFieldDescription(group, schema);
  return group;
}

/**
 * Render a boolean select field
 */
function renderBooleanField(path, key, schema, value) {
  const group = createFormGroup(path, key, schema);
  const select = document.createElement('select');
  select.className = 'form-select';
  select.id = `field-${path.replace(/[.\[\]"]/g, '-')}`;

  const options = [
    { value: '', label: '-- Select --' },
    { value: 'true', label: 'Yes' },
    { value: 'false', label: 'No' }
  ];

  for (const opt of options) {
    const option = document.createElement('option');
    option.value = opt.value;
    option.textContent = opt.label;
    if ((value === true && opt.value === 'true') || (value === false && opt.value === 'false')) {
      option.selected = true;
    }
    select.appendChild(option);
  }

  select.addEventListener('change', () => {
    const boolVal = select.value === 'true' ? true : select.value === 'false' ? false : undefined;
    updateFieldValue(path, boolVal, schema);
  });

  group.appendChild(select);
  addFieldDescription(group, schema);
  return group;
}

/**
 * Render an array field
 */
function renderArrayField(path, key, schema, value) {
  const group = document.createElement('div');
  group.className = 'form-group';
  group.dataset.path = path;
  if (State.hasChanged(path)) {
    group.classList.add('form-group--changed');
  }

  const arrayContainer = document.createElement('div');
  arrayContainer.className = 'array-field';

  const header = document.createElement('div');
  header.className = 'array-field__header';

  // Check if items are file paths
  const isFileArray = schema['x-is-file'] || schema.items?.['x-is-file'];
  const titleIcon = isFileArray ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="16" height="16" style="vertical-align: middle; margin-right: 4px;"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>' : '';

  header.innerHTML = `
    <span class="array-field__title">${titleIcon}${Help.escapeHtml(schema.title || key)}</span>
  `;

  if (Help.createHelpIcon && schema.description) {
    const helpIcon = Help.createHelpIcon(schema, key);
    header.querySelector('.array-field__title').appendChild(helpIcon);
  }

  arrayContainer.appendChild(header);

  const items = document.createElement('div');
  items.className = 'array-field__items';

  const arrValue = Array.isArray(value) ? value : [];
  const itemSchema = schema.items || { type: 'string' };

  arrValue.forEach((item, idx) => {
    const itemPath = `${path}[${idx}]`;
    const itemEl = renderArrayItem(itemPath, idx, itemSchema, item, items);
    items.appendChild(itemEl);
  });

  arrayContainer.appendChild(items);

  // Add button
  const addContainer = document.createElement('div');
  addContainer.className = 'array-field__add';
  const addBtn = document.createElement('button');
  addBtn.type = 'button';
  addBtn.className = 'btn btn--secondary btn--sm';
  addBtn.textContent = '+ Add';
  addBtn.addEventListener('click', () => {
    const newIdx = arrValue.length;
    const newPath = `${path}[${newIdx}]`;
    const defaultVal = itemSchema.type === 'object' ? {} : '';

    // Update data
    if (!Array.isArray(State.getNestedValue(State.state.currentObject, path))) {
      State.setNestedValue(State.state.currentObject, path, []);
    }
    const arr = State.getNestedValue(State.state.currentObject, path);
    arr.push(defaultVal);

    State.recordChange(path, arr);
    triggerFormChange();

    // Refresh array display
    const newItem = renderArrayItem(newPath, newIdx, itemSchema, defaultVal, items);
    items.appendChild(newItem);
  });

  addContainer.appendChild(addBtn);
  arrayContainer.appendChild(addContainer);

  group.appendChild(arrayContainer);
  return group;
}

/**
 * Render a single array item
 */
function renderArrayItem(path, idx, schema, value, container) {
  if (schema.type === 'object') {
    const fieldset = document.createElement('fieldset');
    fieldset.className = 'form-fieldset';
    fieldset.dataset.path = path;

    const legend = document.createElement('legend');
    legend.className = 'form-fieldset__legend';
    legend.innerHTML = `<span class="form-fieldset__toggle">▼</span> Item ${idx + 1}`;

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'btn btn--link btn--sm';
    removeBtn.textContent = '× Remove';
    removeBtn.style.marginLeft = 'auto';
    removeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      removeArrayItem(path, container, fieldset);
    });
    legend.appendChild(removeBtn);

    legend.addEventListener('click', (e) => {
      if (e.target === removeBtn) return;
      fieldset.classList.toggle('form-fieldset--collapsed');
    });

    fieldset.appendChild(legend);

    const content = document.createElement('div');
    content.className = 'form-fieldset__content';
    renderObjectFields(content, schema, path, value || {});
    fieldset.appendChild(content);

    return fieldset;
  }

  // Simple value item
  const item = document.createElement('div');
  item.className = 'array-field__item';
  item.dataset.path = path;

  // Check if this is a file path item
  const isFilePath = schema['x-is-file'];

  if (isFilePath) {
    const fileIcon = document.createElement('span');
    fileIcon.className = 'file-path-icon';
    fileIcon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="16" height="16"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>';
    fileIcon.title = 'File path - will be read when processing locally';
    fileIcon.style.marginRight = '8px';
    item.appendChild(fileIcon);
  }

  const input = document.createElement('input');
  input.type = 'text';
  input.className = isFilePath ? 'form-input form-input--file-path array-field__item-input' : 'form-input array-field__item-input';
  input.value = value || '';
  if (isFilePath) {
    input.placeholder = '/path/to/file';
  }

  input.addEventListener('input', () => {
    updateFieldValue(path, input.value, schema);
  });

  item.appendChild(input);

  const removeBtn = document.createElement('span');
  removeBtn.className = 'array-field__item-remove';
  removeBtn.innerHTML = '×';
  removeBtn.title = 'Remove';
  removeBtn.addEventListener('click', () => {
    removeArrayItem(path, container, item);
  });

  item.appendChild(removeBtn);

  return item;
}

/**
 * Remove an array item
 */
function removeArrayItem(path, container, element) {
  const parts = State.parsePath(path);
  const idx = parts.pop();
  const arrayPath = State.buildPath(parts);

  const arr = State.getNestedValue(State.state.currentObject, arrayPath);
  if (Array.isArray(arr) && typeof idx === 'number') {
    arr.splice(idx, 1);
    State.recordChange(arrayPath, arr);
    triggerFormChange();
  }

  element.remove();

  // Reindex remaining items
  const items = container.querySelectorAll('[data-path]');
  items.forEach((item, newIdx) => {
    const newPath = `${arrayPath}[${newIdx}]`;
    item.dataset.path = newPath;
  });
}

/**
 * Render a nested object field
 */
function renderObjectField(path, key, schema, value) {
  const fieldset = document.createElement('fieldset');
  fieldset.className = 'form-fieldset';
  if (State.hasChanged(path)) {
    fieldset.classList.add('form-group--changed');
  }

  const legend = document.createElement('legend');
  legend.className = 'form-fieldset__legend';
  legend.innerHTML = `<span class="form-fieldset__toggle">▼</span> ${Help.escapeHtml(schema.title || key)}`;

  if (Help.createHelpIcon && schema.description) {
    const helpIcon = Help.createHelpIcon(schema, key);
    legend.appendChild(helpIcon);
  }

  legend.addEventListener('click', () => {
    fieldset.classList.toggle('form-fieldset--collapsed');
  });

  fieldset.appendChild(legend);

  const content = document.createElement('div');
  content.className = 'form-fieldset__content';
  renderObjectFields(content, schema, path, value || {});
  fieldset.appendChild(content);

  return fieldset;
}

/**
 * Render a union type field (anyOf/oneOf)
 */
function renderUnionField(path, key, schema, value) {
  const options = schema.anyOf || schema.oneOf || [];

  // Check for enum + custom string pattern
  const enumOption = options.find(o => o.enum);
  const stringOption = options.find(o => o.type === 'string' && !o.enum);
  const objectOption = options.find(o => o.type === 'object');
  const boolFalseOption = options.find(o => o.const === false);
  const intOrNumOption = options.find(o => o.type === 'integer' || o.type === 'number');

  // Pattern: oneOf [enum/int, {const: false}] - Mode selector
  if (boolFalseOption && (enumOption || intOrNumOption)) {
    return renderModeField(path, key, schema, value, options);
  }

  // Pattern: anyOf [object, string] - Compact mode selector (like storage.os)
  if (objectOption && stringOption && !enumOption) {
    return renderObjectOrStringField(path, key, schema, value, objectOption, stringOption);
  }

  // Pattern: anyOf [enum, string] - Select with "Other" option for custom input
  if (enumOption && stringOption) {
    const mergedSchema = {
      ...enumOption,
      title: schema.title || key,
      description: schema.description || enumOption.description,
      'x-is-file': schema['x-is-file'] || stringOption['x-is-file']
    };
    // Always show enum with Other option - the renderEnumField handles custom values
    return renderEnumField(path, key, mergedSchema, value, true);
  }

  // Pattern: anyOf with only string options (e.g., different formats)
  if (stringOption && !enumOption && !objectOption) {
    const mergedSchema = {
      ...stringOption,
      title: schema.title || key,
      description: schema.description || stringOption.description,
      'x-is-file': schema['x-is-file'] || stringOption['x-is-file']
    };
    return renderStringField(path, key, mergedSchema, value);
  }

  // Default: render based on first option
  if (options.length > 0) {
    const firstOption = options[0];
    return renderField(path, key, { ...firstOption, title: schema.title, description: schema.description }, value);
  }

  return renderStringField(path, key, schema, value);
}

/**
 * Render a field that can be either an object or a string (compact mode)
 */
function renderObjectOrStringField(path, key, schema, value, objectSchema, stringSchema) {
  const group = createFormGroup(path, key, schema);

  // Get current value from state (always fresh)
  const getCurrentValue = () => State.getNestedValue(State.state.currentObject, path);

  // Determine current mode based on actual value type
  const getMode = (val) => {
    if (val !== null && typeof val === 'object') return 'advanced';
    return 'simple';
  };

  const container = document.createElement('div');
  container.className = 'object-or-string-field';

  // Mode selector
  const modeContainer = document.createElement('div');
  modeContainer.className = 'object-or-string-field__mode';
  modeContainer.style.display = 'flex';
  modeContainer.style.gap = '8px';
  modeContainer.style.marginBottom = '8px';

  const modeSelect = document.createElement('select');
  modeSelect.className = 'form-select';
  modeSelect.style.width = 'auto';

  const simpleOpt = document.createElement('option');
  simpleOpt.value = 'simple';
  simpleOpt.textContent = 'Simple (string)';
  modeSelect.appendChild(simpleOpt);

  const advancedOpt = document.createElement('option');
  advancedOpt.value = 'advanced';
  advancedOpt.textContent = 'Advanced (options)';
  modeSelect.appendChild(advancedOpt);

  modeSelect.value = getMode(value);
  modeContainer.appendChild(modeSelect);

  container.appendChild(modeContainer);

  // Content container
  const contentContainer = document.createElement('div');
  contentContainer.className = 'object-or-string-field__content';
  container.appendChild(contentContainer);

  // Render function - always reads fresh value from state
  const renderContent = (mode) => {
    contentContainer.innerHTML = '';
    const currentValue = getCurrentValue();

    if (mode === 'simple') {
      // Simple string input
      const input = document.createElement('input');
      input.type = 'text';
      input.className = 'form-input';
      input.placeholder = stringSchema.description || 'e.g., /dev/sda or wwn-...';
      input.value = typeof currentValue === 'string' ? currentValue : '';

      input.addEventListener('input', () => {
        updateFieldValue(path, input.value || undefined, stringSchema);
      });

      contentContainer.appendChild(input);
    } else {
      // Advanced object with compact grid layout
      const grid = document.createElement('div');
      grid.className = 'compact-object-grid';
      grid.style.display = 'grid';
      grid.style.gridTemplateColumns = 'repeat(auto-fill, minmax(200px, 1fr))';
      grid.style.gap = '8px';

      const objValue = (currentValue !== null && typeof currentValue === 'object') ? currentValue : {};
      const properties = objectSchema.properties || {};
      const rootSchema = State.state?.schema;

      for (const [propKey, rawPropSchema] of Object.entries(properties)) {
        // Resolve $ref if present
        const propSchema = resolveRef(rawPropSchema, rootSchema) || rawPropSchema || {};
        const propType = propSchema.type || 'string';
        const propValue = objValue[propKey];

        const fieldWrapper = document.createElement('div');
        fieldWrapper.className = 'compact-field';

        const label = document.createElement('label');
        label.className = 'compact-field__label';
        label.textContent = propSchema.title || rawPropSchema.title || propKey;
        label.style.fontSize = '0.75rem';
        label.style.color = 'var(--pf-global--Color--200)';
        label.style.display = 'block';
        label.style.marginBottom = '2px';
        fieldWrapper.appendChild(label);

        let input;
        if (propType === 'boolean') {
          input = document.createElement('select');
          input.className = 'form-select form-select--compact';
          input.innerHTML = `
            <option value="">--</option>
            <option value="true" ${propValue === true ? 'selected' : ''}>Yes</option>
            <option value="false" ${propValue === false ? 'selected' : ''}>No</option>
          `;
          input.addEventListener('change', () => {
            const boolVal = input.value === 'true' ? true : input.value === 'false' ? false : undefined;
            updateCompactObjectField(path, propKey, boolVal, objectSchema);
          });
        } else if (propType === 'number' || propType === 'integer') {
          input = document.createElement('input');
          input.type = 'number';
          input.className = 'form-input form-input--compact';
          input.value = propValue !== undefined ? propValue : '';
          if (propSchema.minimum !== undefined) input.min = propSchema.minimum;
          if (propSchema.maximum !== undefined) input.max = propSchema.maximum;
          input.addEventListener('input', () => {
            const numVal = propType === 'integer' ? parseInt(input.value, 10) : parseFloat(input.value);
            updateCompactObjectField(path, propKey, isNaN(numVal) ? undefined : numVal, objectSchema);
          });
        } else if (propType === 'array') {
          input = document.createElement('input');
          input.type = 'text';
          input.className = 'form-input form-input--compact';
          input.placeholder = 'comma-separated';
          input.value = Array.isArray(propValue) ? propValue.join(', ') : '';
          input.addEventListener('input', () => {
            const arrVal = input.value ? input.value.split(',').map(s => s.trim()).filter(s => s) : undefined;
            updateCompactObjectField(path, propKey, arrVal, objectSchema);
          });
        } else {
          input = document.createElement('input');
          input.type = 'text';
          input.className = 'form-input form-input--compact';
          input.value = propValue || '';
          input.placeholder = propSchema.description ? propSchema.description.substring(0, 30) + '...' : '';
          input.addEventListener('input', () => {
            updateCompactObjectField(path, propKey, input.value || undefined, objectSchema);
          });
        }

        input.style.padding = '4px 8px';
        input.style.fontSize = '0.85rem';
        fieldWrapper.appendChild(input);
        grid.appendChild(fieldWrapper);
      }

      contentContainer.appendChild(grid);
    }
  };

  // Initial render
  renderContent(modeSelect.value);

  // Mode change handler - clears value when switching modes to prevent data corruption
  modeSelect.addEventListener('change', () => {
    const newMode = modeSelect.value;
    const currentValue = getCurrentValue();
    const currentMode = getMode(currentValue);

    // Only clear/convert if actually changing modes
    if (newMode !== currentMode) {
      if (newMode === 'simple') {
        // Switching to simple: extract best identifier or clear
        let simpleValue = '';
        if (currentValue && typeof currentValue === 'object') {
          // Priority: wwn > byId > deviceName (preserve the most specific identifier)
          simpleValue = currentValue.wwn || currentValue.byId || currentValue.deviceName || '';
        }
        updateFieldValue(path, simpleValue || undefined, stringSchema);
      } else {
        // Switching to advanced: start with empty object (don't guess field names)
        updateFieldValue(path, {}, objectSchema);
      }
    }
    renderContent(newMode);
  });

  group.appendChild(container);
  addFieldDescription(group, schema);
  return group;
}

/**
 * Update a property within a compact object field
 */
function updateCompactObjectField(basePath, propKey, value, schema) {
  let currentObj = State.getNestedValue(State.state.currentObject, basePath);
  if (!currentObj || typeof currentObj !== 'object') {
    currentObj = {};
  }

  if (value === undefined || value === '' || (Array.isArray(value) && value.length === 0)) {
    delete currentObj[propKey];
  } else {
    currentObj[propKey] = value;
  }

  // Clean empty object
  const hasValues = Object.keys(currentObj).length > 0;
  State.setNestedValue(State.state.currentObject, basePath, hasValues ? currentObj : undefined);
  State.recordChange(basePath, hasValues ? currentObj : undefined);
  triggerFormChange();
}

/**
 * Render a mode selector field (enabled/disabled pattern)
 */
function renderModeField(path, key, schema, value, options) {
  const group = createFormGroup(path, key, schema);

  const container = document.createElement('div');
  container.style.display = 'flex';
  container.style.gap = '8px';
  container.style.alignItems = 'center';

  // Mode toggle
  const modeSelect = document.createElement('select');
  modeSelect.className = 'form-select';
  modeSelect.style.width = 'auto';

  const enabledOpt = document.createElement('option');
  enabledOpt.value = 'enabled';
  enabledOpt.textContent = 'Enabled';
  modeSelect.appendChild(enabledOpt);

  const disabledOpt = document.createElement('option');
  disabledOpt.value = 'disabled';
  disabledOpt.textContent = 'Disabled';
  modeSelect.appendChild(disabledOpt);

  modeSelect.value = value === false ? 'disabled' : 'enabled';

  container.appendChild(modeSelect);

  // Value input (shown when enabled)
  const valueOption = options.find(o => o.enum || o.type === 'integer' || o.type === 'number');
  let valueInput;

  if (valueOption?.enum) {
    valueInput = document.createElement('select');
    valueInput.className = 'form-select';
    valueInput.style.flex = '1';

    for (const opt of valueOption.enum) {
      const option = document.createElement('option');
      option.value = opt;
      option.textContent = opt;
      if (opt === value) option.selected = true;
      valueInput.appendChild(option);
    }
  } else if (valueOption?.type === 'integer' || valueOption?.type === 'number') {
    valueInput = document.createElement('input');
    valueInput.type = 'number';
    valueInput.className = 'form-input form-input--number';
    valueInput.style.flex = '1';
    valueInput.value = typeof value === 'number' ? value : '';

    if (valueOption.minimum !== undefined) valueInput.min = valueOption.minimum;
    if (valueOption.maximum !== undefined) valueInput.max = valueOption.maximum;
    if (valueOption.type === 'integer') valueInput.step = '1';
  }

  if (valueInput) {
    valueInput.disabled = value === false;
    container.appendChild(valueInput);

    modeSelect.addEventListener('change', () => {
      if (modeSelect.value === 'disabled') {
        valueInput.disabled = true;
        updateFieldValue(path, false, schema);
      } else {
        valueInput.disabled = false;
        // Restore previous value or default
        const newVal = valueOption.enum ? valueOption.enum[0] :
          (valueOption.minimum !== undefined ? valueOption.minimum : 0);
        if (valueInput.tagName === 'SELECT') {
          valueInput.value = newVal;
        } else {
          valueInput.value = newVal;
        }
        updateFieldValue(path, State.coerceValue(valueInput.value, valueOption.type, valueOption), schema);
      }
    });

    valueInput.addEventListener('change', () => {
      if (modeSelect.value === 'enabled') {
        updateFieldValue(path, State.coerceValue(valueInput.value, valueOption.type, valueOption), schema);
      }
    });
  }

  group.appendChild(container);
  addFieldDescription(group, schema);
  return group;
}

/**
 * Create a form group wrapper
 */
function createFormGroup(path, key, schema) {
  const group = document.createElement('div');
  group.className = 'form-group';
  group.dataset.path = path;

  if (State.hasChanged(path)) {
    group.classList.add('form-group--changed');
  }

  const label = document.createElement('label');
  label.className = 'form-label';
  label.htmlFor = `field-${path.replace(/[.\[\]"]/g, '-')}`;

  label.innerHTML = Help.escapeHtml(schema.title || key);

  // Required indicator
  if (State.state?.schema?.required?.includes(key)) {
    label.innerHTML += ' <span class="form-label__required">*</span>';
  }

  // Note: x-is-file fields show icon in the input, not a badge in the label

  // Help icon
  if (Help.createHelpIcon && schema.description) {
    const helpIcon = Help.createHelpIcon(schema, key);
    label.appendChild(helpIcon);
  }

  // Revert button (shown for changed fields)
  if (State.hasChanged(path)) {
    const revertBtn = document.createElement('span');
    revertBtn.className = 'revert-btn';
    revertBtn.innerHTML = '↩ Revert';
    revertBtn.title = 'Revert to original value';
    revertBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      e.preventDefault();

      // Get baseline value and set it directly
      const baselineVal = State.getNestedValue(State.state.baselineObject, path);
      State.setNestedValue(State.state.currentObject, path,
        baselineVal === undefined ? undefined : JSON.parse(JSON.stringify(baselineVal)));

      // Trigger form change to sync YAML
      if (onFormChange) {
        onFormChange();
      }

      // Re-render the section to show the reverted value
      // Use a small delay to allow the YAML sync to complete
      setTimeout(() => {
        const container = document.getElementById('form-content');
        if (container && window.ClusterfileEditor) {
          window.ClusterfileEditor.State.state.currentSection &&
            renderSection(window.ClusterfileEditor.State.state.currentSection, container);
        }
      }, 100);
    });
    label.appendChild(revertBtn);
  }

  group.appendChild(label);
  return group;
}

/**
 * Add field description
 */
function addFieldDescription(group, schema) {
  if (schema.description) {
    const desc = document.createElement('div');
    desc.className = 'form-description';
    // Truncate long descriptions
    const text = schema.description.length > 200
      ? schema.description.substring(0, 200) + '...'
      : schema.description;
    desc.textContent = text;
    group.appendChild(desc);
  }
}

/**
 * Update field value in state
 */
function updateFieldValue(path, value, schema) {
  const coercedValue = State.coerceValue(value, schema?.type, schema);

  if (coercedValue === undefined || coercedValue === '') {
    State.deleteNestedValue(State.state.currentObject, path);
  } else {
    State.setNestedValue(State.state.currentObject, path, coercedValue);
  }

  State.recordChange(path, coercedValue);
  triggerFormChange();

  // Update form group changed state - use CSS.escape for paths with special chars
  try {
    const group = document.querySelector(`[data-path="${CSS.escape(path)}"]`);
    if (group) {
      if (State.hasChanged(path)) {
        group.classList.add('form-group--changed');
      } else {
        group.classList.remove('form-group--changed');
      }
    }
  } catch (e) {
    // Ignore selector errors for complex paths
    console.warn('Could not update form group style for path:', path, e);
  }
}

/**
 * Show add host modal
 */
function showAddHostModal() {
  const hostname = prompt('Enter hostname (FQDN):');
  if (!hostname) return;

  // Validate hostname
  const fqdnPattern = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/;
  if (!fqdnPattern.test(hostname)) {
    alert('Invalid hostname. Must be a valid FQDN.');
    return;
  }

  // Check for duplicates
  if (State.state.currentObject.hosts?.[hostname]) {
    alert('A host with this name already exists.');
    return;
  }

  // Add host
  if (!State.state.currentObject.hosts) {
    State.state.currentObject.hosts = {};
  }
  State.state.currentObject.hosts[hostname] = {
    role: 'worker',
    network: {
      interfaces: [],
      primary: {}
    }
  };

  State.recordChange(`hosts["${hostname}"]`, State.state.currentObject.hosts[hostname]);
  triggerFormChange();
}

/**
 * Duplicate a host
 */
function duplicateHost(hostname) {
  const newHostname = prompt('Enter new hostname:', hostname + '-copy');
  if (!newHostname) return;

  // Validate
  const fqdnPattern = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/;
  if (!fqdnPattern.test(newHostname)) {
    alert('Invalid hostname. Must be a valid FQDN.');
    return;
  }

  if (State.state.currentObject.hosts?.[newHostname]) {
    alert('A host with this name already exists.');
    return;
  }

  // Deep clone
  const original = State.state.currentObject.hosts[hostname];
  State.state.currentObject.hosts[newHostname] = JSON.parse(JSON.stringify(original));

  State.recordChange(`hosts["${newHostname}"]`, State.state.currentObject.hosts[newHostname]);
  triggerFormChange();
}

/**
 * Rename a host
 */
function renameHost(hostname) {
  const newHostname = prompt('Enter new hostname:', hostname);
  if (!newHostname || newHostname === hostname) return;

  // Validate
  const fqdnPattern = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/;
  if (!fqdnPattern.test(newHostname)) {
    alert('Invalid hostname. Must be a valid FQDN.');
    return;
  }

  if (State.state.currentObject.hosts?.[newHostname]) {
    alert('A host with this name already exists.');
    return;
  }

  // Rename
  const hostData = State.state.currentObject.hosts[hostname];
  delete State.state.currentObject.hosts[hostname];
  State.state.currentObject.hosts[newHostname] = hostData;

  State.recordChange(`hosts["${hostname}"]`, undefined);
  State.recordChange(`hosts["${newHostname}"]`, hostData);
  triggerFormChange();
}

/**
 * Remove a host
 */
function removeHost(hostname) {
  if (!confirm(`Remove host "${hostname}"?`)) return;

  delete State.state.currentObject.hosts[hostname];
  State.recordChange(`hosts["${hostname}"]`, undefined);
  triggerFormChange();
}

// Export for use in other modules
window.EditorForm = {
  renderSection,
  renderHostsSection,
  renderPluginsSection,
  renderObjectFields,
  renderField,
  setFormChangeCallback,
  triggerFormChange,
  showAddHostModal,
  duplicateHost,
  renameHost,
  removeHost
};

})(); // End IIFE
