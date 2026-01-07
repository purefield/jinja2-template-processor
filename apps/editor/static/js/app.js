(function() {
    'use strict';

    const STORAGE_KEYS = {
        LAST_YAML: 'CLUSTERFILE_LAST_YAML',
        UPLOADED_SCHEMA: 'CLUSTERFILE_UPLOADED_SCHEMA',
        TOUR_SHOWN: 'CLUSTERFILE_TOUR_SHOWN',
        MODE: 'CLUSTERFILE_MODE'
    };

    let templateState = {
        templates: [],
        outputEditor: null,
        lastRenderedOutput: ''
    };

    const SENSITIVE_FIELDS = ['pullSecret', 'password', 'secret'];

    function getApiBase() {
        return window.location.protocol + '//' + window.location.host;
    }

    let state = {
        schema: null,
        baselineYamlText: '',
        currentYamlText: '',
        currentObject: {},
        changes: [],
        currentSection: 'account',
        mode: 'guided',
        editor: null,
        helpTimeout: null,
        pinnedHelp: false,
        currentFilename: 'untitled',
        validationErrors: 0,
        samples: []
    };

    async function init() {
        await loadSchema();
        await loadSamples();
        await loadTemplates();
        initEditor();
        initTemplateOutputEditor();
        initEventListeners();
        initTemplateEventListeners();
        loadSavedState();
        showTourIfNeeded();
        renderCurrentSection();
        updateValidation();
    }

    async function loadSchema() {
        try {
            const uploadedSchema = localStorage.getItem(STORAGE_KEYS.UPLOADED_SCHEMA);
            if (uploadedSchema) {
                state.schema = JSON.parse(uploadedSchema);
            } else {
                const response = await fetch(getApiBase() + '/api/schema');
                state.schema = await response.json();
            }
        } catch (error) {
            console.error('Failed to load schema:', error);
            showError('Failed to load schema');
        }
    }

    async function loadSamples() {
        try {
            const response = await fetch(getApiBase() + '/api/samples');
            const data = await response.json();
            state.samples = data.samples;
            const samplesSelect = document.getElementById('samples-select');
            if (samplesSelect) {
                samplesSelect.innerHTML = '<option value="">Load Sample...</option>';
                data.samples.forEach(sample => {
                    const option = document.createElement('option');
                    option.value = sample.filename;
                    option.textContent = sample.name;
                    samplesSelect.appendChild(option);
                });
            }
        } catch (error) {
            console.error('Failed to load samples:', error);
        }
    }

    function initEditor() {
        const editorElement = document.getElementById('yaml-editor');
        state.editor = CodeMirror(editorElement, {
            mode: 'yaml',
            theme: 'default',
            lineNumbers: true,
            lineWrapping: true,
            tabSize: 2,
            indentWithTabs: false,
            foldGutter: true,
            gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
            extraKeys: {
                'Ctrl-Q': function(cm) { cm.foldCode(cm.getCursor()); }
            }
        });

        state.editor.on('change', debounce(handleEditorChange, 300));
    }

    function initEventListeners() {
        document.querySelectorAll('.pf-c-nav__link[data-section]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                switchSection(link.dataset.section);
            });
        });

        const samplesSelect = document.getElementById('samples-select');
        if (samplesSelect) {
            samplesSelect.addEventListener('change', async (e) => {
                if (e.target.value) {
                    await loadSample(e.target.value);
                    e.target.value = '';
                }
            });
        }

        document.getElementById('btn-new').addEventListener('click', newDocument);
        document.getElementById('btn-load').addEventListener('click', () => document.getElementById('file-input').click());
        document.getElementById('file-input').addEventListener('change', handleFileLoad);
        document.getElementById('btn-save').addEventListener('click', saveToLocalStorage);
        document.getElementById('btn-download').addEventListener('click', downloadYaml);
        document.getElementById('btn-format').addEventListener('click', formatYaml);
        document.getElementById('btn-copy').addEventListener('click', copyYaml);
        document.getElementById('btn-revert-section').addEventListener('click', revertSection);
        document.getElementById('btn-revert-all').addEventListener('click', revertAll);

        document.querySelectorAll('.pf-c-tabs__link').forEach(tab => {
            tab.addEventListener('click', () => switchTab(tab.dataset.tab));
        });

        document.getElementById('tour-close').addEventListener('click', closeTour);

        const versionBadge = document.getElementById('app-version');
        if (versionBadge) {
            versionBadge.addEventListener('click', showChangelog);
            versionBadge.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    showChangelog();
                }
            });
        }
        
        const helpBubble = document.getElementById('help-bubble');
        const helpClose = document.querySelector('.help-bubble-close');
        const helpPin = document.querySelector('.help-bubble-pin');
        
        helpBubble.addEventListener('mousedown', (e) => { e.stopPropagation(); });
        helpBubble.addEventListener('click', (e) => { e.stopPropagation(); });
        helpBubble.addEventListener('mouseenter', handleBubbleEnter);
        helpBubble.addEventListener('mouseleave', handleBubbleLeave);
        helpClose.addEventListener('click', (e) => { e.stopPropagation(); e.preventDefault(); forceHideHelpBubble(); });
        helpClose.addEventListener('mousedown', (e) => { e.stopPropagation(); });
        helpPin.addEventListener('click', (e) => { e.stopPropagation(); e.preventDefault(); togglePinHelp(); });
        helpPin.addEventListener('mousedown', (e) => { e.stopPropagation(); });
    }

    function loadSavedState() {
        const savedMode = localStorage.getItem(STORAGE_KEYS.MODE);
        if (savedMode) {
            setMode(savedMode);
            document.getElementById('mode-toggle').value = savedMode;
        }

        const savedYaml = localStorage.getItem(STORAGE_KEYS.LAST_YAML);
        if (savedYaml) {
            setYamlText(savedYaml, true);
        } else {
            setYamlText(getDefaultYaml(), true);
        }
    }

    function getDefaultYaml() {
        return `account:
  pullSecret: ""

cluster:
  name: ""
  version: "4.20.0"
  platform: baremetal

network:
  domain: ""

hosts: {}

plugins: {}
`;
    }

    function showTourIfNeeded() {
        const tourShown = localStorage.getItem(STORAGE_KEYS.TOUR_SHOWN);
        if (!tourShown) {
            document.getElementById('tour-modal').style.display = 'block';
        }
    }

    function closeTour() {
        document.getElementById('tour-modal').style.display = 'none';
        if (document.getElementById('tour-dont-show').checked) {
            localStorage.setItem(STORAGE_KEYS.TOUR_SHOWN, 'true');
        }
    }

    function showChangelog() {
        switchSection('changelog');
    }

    async function loadChangelog() {
        const content = document.getElementById('changelog-content');
        if (!content) return;
        if (content.dataset.loaded) return;
        try {
            const response = await fetch('/static/changelog.md', { cache: 'no-cache' });
            content.textContent = await response.text();
            content.dataset.loaded = 'true';
        } catch (error) {
            content.textContent = 'Failed to load changelog.';
        }
    }

    function setMode(mode) {
        state.mode = mode;
        localStorage.setItem(STORAGE_KEYS.MODE, mode);
        document.body.classList.remove('guided-mode', 'advanced-mode');
        document.body.classList.add(mode + '-mode');
    }

    function switchSection(section) {
        state.currentSection = section;
        document.querySelectorAll('.pf-c-nav__link[data-section]').forEach(link => {
            link.classList.toggle('pf-m-current', link.dataset.section === section);
        });
        document.getElementById('section-title').textContent = capitalizeFirst(section);
        
        const formContainer = document.getElementById('form-container');
        const templatesContainer = document.getElementById('templates-container');
        const changelogContainer = document.getElementById('changelog-container');
        const editorPane = document.getElementById('editor-pane');
        const formActions = document.querySelector('.form-actions');
        
        if (section === 'templates') {
            formContainer.style.display = 'none';
            templatesContainer.style.display = 'block';
            if (changelogContainer) changelogContainer.style.display = 'none';
            editorPane.style.display = 'none';
            if (formActions) formActions.style.display = 'none';
        } else if (section === 'changelog') {
            formContainer.style.display = 'none';
            templatesContainer.style.display = 'none';
            if (changelogContainer) changelogContainer.style.display = 'block';
            editorPane.style.display = 'none';
            if (formActions) formActions.style.display = 'none';
            loadChangelog();
        } else {
            formContainer.style.display = 'block';
            templatesContainer.style.display = 'none';
            if (changelogContainer) changelogContainer.style.display = 'none';
            editorPane.style.display = 'flex';
            if (formActions) formActions.style.display = 'flex';
            renderCurrentSection();
        }
    }

    function switchTab(tab) {
        document.querySelectorAll('.pf-c-tabs__item').forEach(item => {
            item.classList.toggle('pf-m-current', item.querySelector('.pf-c-tabs__link').dataset.tab === tab);
        });
        document.querySelectorAll('.tab-panel').forEach(panel => {
            panel.classList.toggle('active', panel.id === 'panel-' + tab);
        });
    }

    async function loadSample(filename) {
        try {
            const response = await fetch(getApiBase() + `/api/samples/${filename}`);
            const data = await response.json();
            setYamlText(data.content, true);
            state.currentFilename = filename;
            updateHeaderStatus();
        } catch (error) {
            console.error('Failed to load sample:', error);
            showError('Failed to load sample');
        }
    }

    function setYamlText(yamlText, isBaseline = false) {
        try {
            state.currentYamlText = yamlText;
            const parsedObject = jsyaml.load(yamlText) || {};
            state.currentObject = state.schema ? coerceValueBySchema(parsedObject, state.schema) : parsedObject;
            
            if (isBaseline) {
                state.baselineYamlText = yamlText;
                state.changes = [];
            }
            
            state.editor.setValue(yamlText);
            renderCurrentSection();
            updateValidation();
            updateChanges();
            updateDiff();
        } catch (error) {
            console.error('Failed to parse YAML:', error);
            showParseError(error);
        }
    }

    function handleEditorChange() {
        const newYaml = state.editor.getValue();
        if (newYaml === state.currentYamlText) return;

        try {
            const newObject = jsyaml.load(newYaml);
            state.currentYamlText = newYaml;
            const parsedObject = newObject || {};
            state.currentObject = state.schema ? coerceValueBySchema(parsedObject, state.schema) : parsedObject;
            renderCurrentSection();
            updateValidation();
            updateChanges();
            updateDiff();
            clearParseError();
        } catch (error) {
            showParseError(error);
        }
    }

    function renderCurrentSection() {
        const container = document.getElementById('form-container');
        container.innerHTML = '';

        if (!state.schema || !state.schema.properties) return;

        const section = state.currentSection;
        const sectionSchema = state.schema.properties[section];
        const sectionData = state.currentObject[section] || {};

        if (section === 'hosts') {
            renderHostsSection(container, sectionSchema, sectionData);
        } else {
            renderObjectFields(container, sectionSchema, sectionData, section);
        }
    }

    function renderObjectFields(container, schema, data, path) {
        if (!schema || !schema.properties) {
            if (schema && schema.patternProperties) {
                renderPatternProperties(container, schema, data, path);
            }
            return;
        }

        Object.entries(schema.properties).forEach(([key, propSchema]) => {
            const fieldPath = path ? `${path}.${key}` : key;
            const value = data ? data[key] : undefined;
            renderField(container, key, propSchema, value, fieldPath);
        });
    }

    function renderField(container, key, schema, value, path) {
        const group = document.createElement('div');
        group.className = 'form-group';
        group.dataset.path = path;

        const isChanged = hasChanged(path);
        if (isChanged) {
            group.classList.add('has-changes');
        }

        const fieldRow = document.createElement('div');
        fieldRow.className = 'field-row';

        const labelSpan = document.createElement('span');
        labelSpan.className = 'field-label';
        labelSpan.textContent = schema.title || capitalizeFirst(key);
        fieldRow.appendChild(labelSpan);

        const inputWrapper = document.createElement('div');
        inputWrapper.className = 'field-input-wrapper';

        if (schema['x-is-file']) {
            renderFileField(inputWrapper, key, schema, value, path);
        } else if (schema.type === 'array' || Array.isArray(value)) {
            renderArrayField(inputWrapper, key, schema, value, path);
        } else if (schema.anyOf || schema.oneOf) {
            renderAnyOfField(inputWrapper, key, schema, value, path);
        } else if (schema.type === 'object' || (value !== null && typeof value === 'object' && !Array.isArray(value))) {
            renderNestedObjectField(inputWrapper, key, schema, value, path);
        } else if (schema.enum) {
            renderEnumField(inputWrapper, key, schema, value, path);
        } else if (schema.type === 'boolean') {
            renderBooleanField(inputWrapper, key, schema, value, path);
        } else if (schema.type === 'integer' || schema.type === 'number') {
            renderNumberField(inputWrapper, key, schema, value, path);
        } else {
            renderTextField(inputWrapper, key, schema, value, path);
        }

        fieldRow.appendChild(inputWrapper);

        const helpIcon = document.createElement('span');
        helpIcon.className = 'help-icon';
        helpIcon.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 17h-2v-2h2v2zm2.07-7.75l-.9.92C13.45 12.9 13 13.5 13 15h-2v-.5c0-1.1.45-2.1 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41 0-1.1-.9-2-2-2s-2 .9-2 2H8c0-2.21 1.79-4 4-4s4 1.79 4 4c0 .88-.36 1.68-.93 2.25z"/></svg>';
        helpIcon.dataset.description = schema.description || '';
        helpIcon.dataset.docUrl = getDocUrl(schema);
        helpIcon.addEventListener('mouseenter', handleHelpHover);
        helpIcon.addEventListener('mouseleave', handleHelpLeave);
        helpIcon.addEventListener('mousedown', (e) => { e.stopPropagation(); e.preventDefault(); });
        helpIcon.addEventListener('click', (e) => { e.stopPropagation(); e.preventDefault(); });
        fieldRow.appendChild(helpIcon);

        const revertBtn = document.createElement('button');
        revertBtn.className = 'revert-btn';
        revertBtn.innerHTML = '&#x21BA;';
        revertBtn.title = 'Revert to original value';
        revertBtn.dataset.path = path;
        revertBtn.addEventListener('click', (e) => { e.stopPropagation(); revertField(e.target.dataset.path); });
        fieldRow.appendChild(revertBtn);

        group.appendChild(fieldRow);

        if (schema.description) {
            const desc = document.createElement('div');
            desc.className = 'field-description';
            desc.textContent = schema.description.substring(0, 100) + (schema.description.length > 100 ? '...' : '');
            group.appendChild(desc);
        }

        container.appendChild(group);
    }

    function renderTextField(group, key, schema, value, path) {
        if (Array.isArray(value)) {
            renderArrayField(group, key, schema.items ? schema : { type: 'array', items: { type: 'string' } }, value, path);
            return;
        }
        if (value !== null && typeof value === 'object') {
            renderNestedObjectField(group, key, schema.properties ? schema : { type: 'object', properties: {} }, value, path);
            return;
        }
        const input = document.createElement('input');
        input.type = 'text';
        input.value = value !== undefined ? String(value) : '';
        input.placeholder = schema.default || '';
        input.dataset.path = path;
        if (hasChanged(path)) input.classList.add('changed');
        input.addEventListener('input', (e) => updateFieldValue(path, e.target.value));
        group.appendChild(input);
    }

    function renderNumberField(group, key, schema, value, path) {
        const input = document.createElement('input');
        input.type = 'number';
        input.value = value !== undefined ? value : '';
        input.placeholder = schema.default !== undefined ? schema.default : '';
        if (schema.minimum !== undefined) input.min = schema.minimum;
        if (schema.maximum !== undefined) input.max = schema.maximum;
        input.dataset.path = path;
        if (hasChanged(path)) input.classList.add('changed');
        input.addEventListener('input', (e) => {
            const val = e.target.value === '' ? undefined : Number(e.target.value);
            updateFieldValue(path, val);
        });
        group.appendChild(input);
    }

    function renderBooleanField(group, key, schema, value, path) {
        const select = document.createElement('select');
        select.dataset.path = path;
        select.innerHTML = `
            <option value="">-- Select --</option>
            <option value="true" ${value === true ? 'selected' : ''}>Yes</option>
            <option value="false" ${value === false ? 'selected' : ''}>No</option>
        `;
        if (hasChanged(path)) select.classList.add('changed');
        select.addEventListener('change', (e) => {
            const val = e.target.value === '' ? undefined : e.target.value === 'true';
            updateFieldValue(path, val);
        });
        group.appendChild(select);
    }

    function renderEnumField(group, key, schema, value, path) {
        const select = document.createElement('select');
        select.dataset.path = path;
        select.innerHTML = `<option value="">-- Select --</option>`;
        schema.enum.forEach(opt => {
            const option = document.createElement('option');
            option.value = opt;
            option.textContent = opt;
            option.selected = value === opt;
            select.appendChild(option);
        });
        if (hasChanged(path)) select.classList.add('changed');
        select.addEventListener('change', (e) => updateFieldValue(path, e.target.value || undefined));
        group.appendChild(select);
    }

    function renderAnyOfField(group, key, schema, value, path) {
        const options = schema.anyOf || schema.oneOf;
        const enumOption = options.find(o => o.enum);
        const objectOption = options.find(o => o.type === 'object');
        const stringOption = options.find(o => o.type === 'string' && !o.enum);
        const numberOption = options.find(o => o.type === 'number' || o.type === 'integer');
        const booleanFalseOption = options.find(o => o.type === 'boolean' && o.const === false);
        const booleanTrueOption = options.find(o => o.type === 'boolean' && o.const === true);

        const wrapper = document.createElement('div');
        wrapper.className = 'anyof-field';

        if (numberOption && (booleanFalseOption || booleanTrueOption) && !enumOption && !objectOption && !stringOption) {
            const select = document.createElement('select');
            select.className = 'anyof-mode-select';
            const valueIsNumeric = typeof value === 'number' || (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value)));
            const currentMode = valueIsNumeric ? 'number' : (value === false ? 'false' : (value === true ? 'true' : ''));

            const falseLabel = booleanFalseOption ? 'Disabled' : 'False';
            const trueLabel = booleanTrueOption ? 'Enabled' : 'True';

            select.innerHTML = `
                <option value="">-- Select --</option>
                <option value="number" ${currentMode === 'number' ? 'selected' : ''}>Value</option>
                ${booleanFalseOption ? `<option value="false" ${currentMode === 'false' ? 'selected' : ''}>${falseLabel}</option>` : ''}
                ${booleanTrueOption ? `<option value="true" ${currentMode === 'true' ? 'selected' : ''}>${trueLabel}</option>` : ''}
            `;
            wrapper.appendChild(select);

            const numberInput = document.createElement('input');
            numberInput.type = 'number';
            numberInput.value = valueIsNumeric ? Number(value) : '';
            numberInput.placeholder = numberOption.description ? numberOption.description.substring(0, 50) : '';
            if (numberOption.minimum !== undefined) numberInput.min = numberOption.minimum;
            if (numberOption.maximum !== undefined) numberInput.max = numberOption.maximum;
            numberInput.style.display = currentMode === 'number' ? 'block' : 'none';
            numberInput.addEventListener('input', (e) => {
                if (e.target.value === '') {
                    updateFieldValue(path, undefined);
                } else {
                    const parsed = numberOption.type === 'integer' ? parseInt(e.target.value, 10) : Number(e.target.value);
                    updateFieldValue(path, parsed);
                }
            });
            wrapper.appendChild(numberInput);

            select.addEventListener('change', (e) => {
                const mode = e.target.value;
                if (mode === 'number') {
                    numberInput.style.display = 'block';
                    if (numberInput.value === '') {
                        updateFieldValue(path, undefined);
                    } else {
                        const parsed = numberOption.type === 'integer' ? parseInt(numberInput.value, 10) : Number(numberInput.value);
                        updateFieldValue(path, parsed);
                    }
                } else {
                    numberInput.style.display = 'none';
                    if (mode === 'false') {
                        updateFieldValue(path, false);
                    } else if (mode === 'true') {
                        updateFieldValue(path, true);
                    } else {
                        updateFieldValue(path, undefined);
                    }
                }
            });
        } else if (objectOption && stringOption && !enumOption) {
            const isObject = value !== null && typeof value === 'object';
            
            const modeSelect = document.createElement('select');
            modeSelect.className = 'anyof-mode-select';
            modeSelect.innerHTML = `
                <option value="structured" ${isObject ? 'selected' : ''}>Structured</option>
                <option value="simple" ${!isObject ? 'selected' : ''}>Simple String</option>
            `;
            wrapper.appendChild(modeSelect);

            const structuredContainer = document.createElement('div');
            structuredContainer.className = 'anyof-structured';
            structuredContainer.style.display = isObject ? 'block' : 'none';
            
            const propsToRender = objectOption.properties || {};
            const valueKeys = isObject && value ? Object.keys(value) : [];
            valueKeys.forEach(k => {
                if (!propsToRender[k]) {
                    propsToRender[k] = { type: 'string', title: capitalizeFirst(k) };
                }
            });
            
            if (Object.keys(propsToRender).length > 0) {
                Object.entries(propsToRender).forEach(([propKey, propSchema]) => {
                    const propPath = `${path}.${propKey}`;
                    const propValue = isObject && value ? value[propKey] : undefined;
                    const propGroup = document.createElement('div');
                    propGroup.className = 'nested-field';
                    
                    const propLabel = document.createElement('span');
                    propLabel.className = 'nested-field-label';
                    propLabel.textContent = propSchema.title || capitalizeFirst(propKey);
                    propGroup.appendChild(propLabel);
                    
                    const propType = propSchema.type || (Array.isArray(propValue) ? 'array' : typeof propValue === 'boolean' ? 'boolean' : typeof propValue === 'number' ? 'number' : 'string');
                    
                    if (propType === 'boolean') {
                        const select = document.createElement('select');
                        select.dataset.path = propPath;
                        select.innerHTML = `
                            <option value="">-- Select --</option>
                            <option value="true" ${propValue === true ? 'selected' : ''}>Yes</option>
                            <option value="false" ${propValue === false ? 'selected' : ''}>No</option>
                        `;
                        select.addEventListener('change', (e) => {
                            let currentVal = getNestedValue(state.currentObject, path);
                            if (typeof currentVal !== 'object' || currentVal === null) {
                                currentVal = {};
                            }
                            if (e.target.value !== '') {
                                currentVal[propKey] = e.target.value === 'true';
                            } else {
                                delete currentVal[propKey];
                            }
                            if (Object.keys(currentVal).length === 0) {
                                updateFieldValue(path, undefined);
                            } else {
                                updateFieldValue(path, currentVal);
                            }
                        });
                        propGroup.appendChild(select);
                    } else if (propType === 'number' || propType === 'integer') {
                        const propInput = document.createElement('input');
                        propInput.type = 'number';
                        propInput.value = propValue !== undefined ? propValue : '';
                        propInput.placeholder = propSchema.description ? propSchema.description.substring(0, 50) : '';
                        propInput.dataset.path = propPath;
                        if (propSchema.minimum !== undefined) propInput.min = propSchema.minimum;
                        if (propSchema.maximum !== undefined) propInput.max = propSchema.maximum;
                        propInput.addEventListener('input', (e) => {
                            let currentVal = getNestedValue(state.currentObject, path);
                            if (typeof currentVal !== 'object' || currentVal === null) {
                                currentVal = {};
                            }
                            if (e.target.value !== '') {
                                currentVal[propKey] = parseFloat(e.target.value);
                            } else {
                                delete currentVal[propKey];
                            }
                            if (Object.keys(currentVal).length === 0) {
                                updateFieldValue(path, undefined);
                            } else {
                                updateFieldValue(path, currentVal);
                            }
                        });
                        propGroup.appendChild(propInput);
                    } else if (propType === 'array') {
                        const arrayContainer = document.createElement('div');
                        arrayContainer.className = 'nested-array-field';
                        const items = Array.isArray(propValue) ? propValue : [];
                        items.forEach((item, idx) => {
                            const itemRow = document.createElement('div');
                            itemRow.className = 'nested-array-item';
                            const itemInput = document.createElement('input');
                            itemInput.type = 'text';
                            itemInput.value = item || '';
                            itemInput.addEventListener('input', (e) => {
                                let currentVal = getNestedValue(state.currentObject, path);
                                if (typeof currentVal !== 'object' || currentVal === null) {
                                    currentVal = {};
                                }
                                if (!Array.isArray(currentVal[propKey])) {
                                    currentVal[propKey] = [];
                                }
                                currentVal[propKey][idx] = e.target.value;
                                updateFieldValue(path, currentVal);
                            });
                            itemRow.appendChild(itemInput);
                            const removeBtn = document.createElement('button');
                            removeBtn.type = 'button';
                            removeBtn.className = 'nested-array-remove';
                            removeBtn.textContent = 'X';
                            removeBtn.addEventListener('click', () => {
                                let currentVal = getNestedValue(state.currentObject, path);
                                if (currentVal && Array.isArray(currentVal[propKey])) {
                                    currentVal[propKey].splice(idx, 1);
                                    if (currentVal[propKey].length === 0) {
                                        delete currentVal[propKey];
                                    }
                                    if (Object.keys(currentVal).length === 0) {
                                        updateFieldValue(path, undefined);
                                    } else {
                                        updateFieldValue(path, currentVal);
                                    }
                                    renderCurrentSection();
                                }
                            });
                            itemRow.appendChild(removeBtn);
                            arrayContainer.appendChild(itemRow);
                        });
                        const addBtn = document.createElement('button');
                        addBtn.type = 'button';
                        addBtn.className = 'nested-array-add';
                        addBtn.textContent = '+ Add';
                        addBtn.addEventListener('click', () => {
                            let currentVal = getNestedValue(state.currentObject, path);
                            if (typeof currentVal !== 'object' || currentVal === null) {
                                currentVal = {};
                            }
                            if (!Array.isArray(currentVal[propKey])) {
                                currentVal[propKey] = [];
                            }
                            currentVal[propKey].push('');
                            updateFieldValue(path, currentVal);
                            renderCurrentSection();
                        });
                        arrayContainer.appendChild(addBtn);
                        propGroup.appendChild(arrayContainer);
                    } else {
                        const propInput = document.createElement('input');
                        propInput.type = 'text';
                        propInput.value = propValue !== undefined ? propValue : '';
                        propInput.placeholder = propSchema.description ? propSchema.description.substring(0, 50) : '';
                        propInput.dataset.path = propPath;
                        propInput.addEventListener('input', (e) => {
                            let currentVal = getNestedValue(state.currentObject, path);
                            if (typeof currentVal !== 'object' || currentVal === null) {
                                currentVal = {};
                            }
                            if (e.target.value) {
                                currentVal[propKey] = e.target.value;
                            } else {
                                delete currentVal[propKey];
                            }
                            if (Object.keys(currentVal).length === 0) {
                                updateFieldValue(path, undefined);
                            } else {
                                updateFieldValue(path, currentVal);
                            }
                        });
                        propGroup.appendChild(propInput);
                    }
                    structuredContainer.appendChild(propGroup);
                });
            }
            wrapper.appendChild(structuredContainer);

            const simpleContainer = document.createElement('div');
            simpleContainer.className = 'anyof-simple';
            simpleContainer.style.display = isObject ? 'none' : 'block';
            
            const simpleInput = document.createElement('input');
            simpleInput.type = 'text';
            simpleInput.value = !isObject && value ? value : '';
            simpleInput.placeholder = stringOption.description ? stringOption.description.substring(0, 50) : 'Enter value...';
            simpleInput.dataset.path = path;
            if (hasChanged(path)) simpleInput.classList.add('changed');
            simpleInput.addEventListener('input', (e) => updateFieldValue(path, e.target.value || undefined));
            simpleContainer.appendChild(simpleInput);
            wrapper.appendChild(simpleContainer);

            modeSelect.addEventListener('change', (e) => {
                const isStructured = e.target.value === 'structured';
                structuredContainer.style.display = isStructured ? 'block' : 'none';
                simpleContainer.style.display = isStructured ? 'none' : 'block';
                if (isStructured) {
                    updateFieldValue(path, {});
                } else {
                    updateFieldValue(path, '');
                }
            });
        } else if (enumOption && enumOption.enum) {
            const select = document.createElement('select');
            select.dataset.path = path;
            select.innerHTML = `<option value="">-- Select --</option>`;
            enumOption.enum.forEach(opt => {
                const option = document.createElement('option');
                option.value = opt;
                option.textContent = opt;
                option.selected = value === opt;
                select.appendChild(option);
            });
            select.innerHTML += `<option value="__custom__" ${value && !enumOption.enum.includes(value) ? 'selected' : ''}>Custom...</option>`;
            
            const customInput = document.createElement('input');
            customInput.type = 'text';
            customInput.placeholder = 'Enter custom value';
            customInput.style.display = (value && !enumOption.enum.includes(value)) ? 'block' : 'none';
            customInput.style.marginTop = '8px';
            customInput.value = (value && !enumOption.enum.includes(value)) ? value : '';

            select.addEventListener('change', (e) => {
                if (e.target.value === '__custom__') {
                    customInput.style.display = 'block';
                    customInput.focus();
                } else {
                    customInput.style.display = 'none';
                    updateFieldValue(path, e.target.value || undefined);
                }
            });

            customInput.addEventListener('input', (e) => {
                updateFieldValue(path, e.target.value || undefined);
            });

            wrapper.appendChild(select);
            wrapper.appendChild(customInput);
        } else {
            renderTextField(wrapper, key, schema, value, path);
        }

        group.appendChild(wrapper);
    }

    function renderFileField(group, key, schema, value, path) {
        const wrapper = document.createElement('div');
        wrapper.className = 'file-field';

        const input = document.createElement('input');
        input.type = 'text';
        input.value = value || '';
        input.placeholder = 'Path to file...';
        input.dataset.path = path;
        if (hasChanged(path)) input.classList.add('changed');
        input.addEventListener('input', (e) => updateFieldValue(path, e.target.value || undefined));

        const indicator = document.createElement('span');
        indicator.className = 'file-indicator';
        indicator.textContent = 'File Path';

        wrapper.appendChild(input);
        wrapper.appendChild(indicator);
        group.appendChild(wrapper);
    }

    function renderArrayField(group, key, schema, value, path) {
        const wrapper = document.createElement('div');
        wrapper.className = 'array-field';
        wrapper.dataset.path = path;

        const items = Array.isArray(value) ? value : [];
        const itemSchema = schema.items || {};

        items.forEach((item, index) => {
            const itemPath = `${path}[${index}]`;
            if (itemSchema.type === 'object') {
                renderArrayObjectItem(wrapper, itemSchema, item, itemPath, index);
            } else {
                renderArrayPrimitiveItem(wrapper, itemSchema, item, itemPath, index);
            }
        });

        const addBtn = document.createElement('button');
        addBtn.className = 'array-add-btn';
        addBtn.textContent = '+ Add Item';
        addBtn.addEventListener('click', () => addArrayItem(path, itemSchema));
        wrapper.appendChild(addBtn);

        group.appendChild(wrapper);
    }

    function renderArrayPrimitiveItem(wrapper, schema, value, path, index) {
        const item = document.createElement('div');
        item.className = 'array-item';

        const input = document.createElement('input');
        input.type = schema.type === 'number' || schema.type === 'integer' ? 'number' : 'text';
        input.value = value !== undefined ? value : '';
        input.dataset.path = path;
        input.addEventListener('input', (e) => {
            const val = schema.type === 'number' || schema.type === 'integer' 
                ? (e.target.value === '' ? undefined : Number(e.target.value))
                : e.target.value;
            updateArrayItemValue(path, val);
        });

        const removeBtn = document.createElement('button');
        removeBtn.className = 'remove-btn';
        removeBtn.textContent = 'Remove';
        removeBtn.addEventListener('click', () => removeArrayItem(path));

        item.appendChild(input);
        item.appendChild(removeBtn);
        wrapper.appendChild(item);
    }

    function renderArrayObjectItem(wrapper, schema, value, path, index) {
        const item = document.createElement('div');
        item.className = 'array-item object-item';
        
        const content = document.createElement('div');
        content.className = 'object-field';
        content.style.flex = '1';
        
        renderObjectFields(content, schema, value, path);

        const removeBtn = document.createElement('button');
        removeBtn.className = 'remove-btn';
        removeBtn.textContent = 'Remove';
        removeBtn.style.alignSelf = 'flex-start';
        removeBtn.addEventListener('click', () => removeArrayItem(path));

        item.appendChild(content);
        item.appendChild(removeBtn);
        wrapper.appendChild(item);
    }

    function renderNestedObjectField(group, key, schema, value, path) {
        const wrapper = document.createElement('div');
        wrapper.className = 'object-field';
        
        const header = document.createElement('div');
        header.className = 'object-field-header';
        header.innerHTML = `<h4>${schema.title || capitalizeFirst(key)}</h4>`;
        wrapper.appendChild(header);

        renderObjectFields(wrapper, schema, value || {}, path);
        group.appendChild(wrapper);
    }

    function renderHostsSection(container, schema, data) {
        const toolbar = document.createElement('div');
        toolbar.className = 'hosts-toolbar';
        toolbar.innerHTML = `
            <h3>Hosts (${Object.keys(data || {}).length})</h3>
            <button class="add-host-btn">+ Add Host</button>
        `;
        toolbar.querySelector('.add-host-btn').addEventListener('click', addHost);
        container.appendChild(toolbar);

        const hostsContainer = document.createElement('div');
        hostsContainer.id = 'hosts-container';

        Object.entries(data || {}).forEach(([hostname, hostData]) => {
            renderHostCard(hostsContainer, hostname, hostData, schema);
        });

        container.appendChild(hostsContainer);
    }

    function renderHostCard(container, hostname, data, schema) {
        const card = document.createElement('div');
        card.className = 'host-card collapsed';
        card.dataset.hostname = hostname;

        const role = data.role || 'worker';
        const roleClass = role === 'control' ? 'control' : '';

        card.innerHTML = `
            <div class="host-card-header">
                <h4>
                    <span class="hostname">${hostname}</span>
                    <span class="role-badge ${roleClass}">${role}</span>
                </h4>
                <div class="host-card-actions">
                    <button class="duplicate-btn" title="Duplicate host">Duplicate</button>
                    <button class="remove-btn" title="Remove host">Remove</button>
                    <button class="toggle-btn">Expand</button>
                </div>
            </div>
            <div class="host-card-body"></div>
        `;

        const header = card.querySelector('.host-card-header');
        const body = card.querySelector('.host-card-body');
        const toggleBtn = card.querySelector('.toggle-btn');

        header.addEventListener('click', (e) => {
            if (e.target.tagName === 'BUTTON') return;
            toggleHostCard(card);
        });

        toggleBtn.addEventListener('click', () => toggleHostCard(card));
        card.querySelector('.duplicate-btn').addEventListener('click', () => duplicateHost(hostname));
        card.querySelector('.remove-btn').addEventListener('click', () => removeHost(hostname));

        const hostSchema = getHostSchema(schema);
        renderHostFields(body, hostSchema, data, buildHostPath(hostname));

        container.appendChild(card);
    }

    function getHostSchema(schema) {
        if (schema.patternProperties) {
            const patterns = Object.values(schema.patternProperties);
            if (patterns.length > 0) return patterns[0];
        }
        return { type: 'object', properties: {} };
    }

    function renderHostFields(container, schema, data, path) {
        const hostname = getHostnameFromPath(path);
        const hostnameGroup = document.createElement('div');
        hostnameGroup.className = 'form-group';
        hostnameGroup.innerHTML = `
            <label>Hostname</label>
            <input type="text" value="${escapeHtml(hostname)}" data-hostname-input="true" />
        `;
        hostnameGroup.querySelector('input').addEventListener('change', (e) => {
            renameHost(hostname, e.target.value);
        });
        container.appendChild(hostnameGroup);

        renderObjectFields(container, schema, data, path);
    }

    function toggleHostCard(card) {
        card.classList.toggle('collapsed');
        card.classList.toggle('expanded');
        const btn = card.querySelector('.toggle-btn');
        btn.textContent = card.classList.contains('expanded') ? 'Collapse' : 'Expand';
    }

    function addHost() {
        const hostname = prompt('Enter hostname:', `host-${Object.keys(state.currentObject.hosts || {}).length}`);
        if (!hostname) return;

        if (!state.currentObject.hosts) {
            state.currentObject.hosts = {};
        }

        state.currentObject.hosts[hostname] = {
            role: 'worker',
            network: {
                interfaces: [],
                primary: {}
            }
        };

        syncObjectToYaml();
        renderCurrentSection();
    }

    function duplicateHost(hostname) {
        const newHostname = prompt('Enter new hostname:', `${hostname}-copy`);
        if (!newHostname || newHostname === hostname) return;

        const hostData = JSON.parse(JSON.stringify(state.currentObject.hosts[hostname]));
        state.currentObject.hosts[newHostname] = hostData;

        syncObjectToYaml();
        renderCurrentSection();
    }

    function removeHost(hostname) {
        if (!confirm(`Remove host "${hostname}"?`)) return;

        delete state.currentObject.hosts[hostname];
        syncObjectToYaml();
        renderCurrentSection();
    }

    function renameHost(oldName, newName) {
        if (oldName === newName || !newName) return;

        const hostData = state.currentObject.hosts[oldName];
        delete state.currentObject.hosts[oldName];
        state.currentObject.hosts[newName] = hostData;

        syncObjectToYaml();
        renderCurrentSection();
    }

    function updateFieldValue(path, value) {
        setNestedValue(state.currentObject, path, value);
        trackChange(path, value);
        syncObjectToYaml();
    }

    function updateArrayItemValue(path, value) {
        const match = path.match(/^(.+)\[(\d+)\]$/);
        if (!match) return;

        const arrayPath = match[1];
        const index = parseInt(match[2]);
        const array = getNestedValue(state.currentObject, arrayPath);
        
        if (Array.isArray(array)) {
            array[index] = value;
            syncObjectToYaml();
        }
    }

    function addArrayItem(path, schema) {
        let array = getNestedValue(state.currentObject, path);
        if (!Array.isArray(array)) {
            array = [];
            setNestedValue(state.currentObject, path, array);
        }

        let defaultValue;
        if (schema.type === 'object') {
            defaultValue = {};
        } else if (schema.type === 'string') {
            defaultValue = '';
        } else if (schema.type === 'number' || schema.type === 'integer') {
            defaultValue = 0;
        } else {
            defaultValue = null;
        }

        array.push(defaultValue);
        syncObjectToYaml();
        renderCurrentSection();
    }

    function removeArrayItem(path) {
        const match = path.match(/^(.+)\[(\d+)\]$/);
        if (!match) return;

        const arrayPath = match[1];
        const index = parseInt(match[2]);
        const array = getNestedValue(state.currentObject, arrayPath);
        
        if (Array.isArray(array)) {
            array.splice(index, 1);
            syncObjectToYaml();
            renderCurrentSection();
        }
    }

    function syncObjectToYaml() {
        try {
            const coercedObject = state.schema ? coerceValueBySchema(state.currentObject, state.schema) : state.currentObject;
            const baselineObject = jsyaml.load(state.baselineYamlText) || {};
            const cleanedObject = cleanObject(coercedObject, baselineObject);
            state.currentObject = coercedObject || {};
            state.currentYamlText = jsyaml.dump(cleanedObject, {
                indent: 2,
                lineWidth: -1,
                noRefs: true,
                sortKeys: false
            });
            state.editor.setValue(state.currentYamlText);
            updateValidation();
            updateChanges();
            updateDiff();
        } catch (error) {
            console.error('Failed to sync to YAML:', error);
        }
    }

    function cleanObject(obj, baselineObj, path = '') {
        if (obj === null || obj === undefined) return undefined;
        if (typeof obj !== 'object') return obj;
        if (Array.isArray(obj)) {
            const cleaned = obj
                .map((item, index) => cleanObject(item, baselineObj, `${path}[${index}]`))
                .filter(v => v !== undefined);
            return cleaned.length > 0 ? cleaned : undefined;
        }

        const cleaned = {};
        const baselineNode = baselineObj ? (path ? getNestedValue(baselineObj, path) : baselineObj) : undefined;
        const baselineKeys = baselineNode && typeof baselineNode === 'object' && !Array.isArray(baselineNode)
            ? Object.keys(baselineNode)
            : [];
        const objKeys = Object.keys(obj);
        const orderedKeys = baselineKeys.concat(objKeys.filter(k => !baselineKeys.includes(k)));

        for (const key of orderedKeys) {
            if (!Object.prototype.hasOwnProperty.call(obj, key)) continue;
            const value = obj[key];
            const nextPath = path ? `${path}.${key}` : key;
            const cleanedValue = cleanObject(value, baselineObj, nextPath);
            const baselineValue = baselineObj ? getNestedValue(baselineObj, nextPath) : undefined;
            const allowEmptyString = cleanedValue === '' && baselineValue === '';
            if (cleanedValue !== undefined &&
                (cleanedValue !== '' || allowEmptyString) &&
                !(typeof cleanedValue === 'object' && Object.keys(cleanedValue).length === 0)) {
                cleaned[key] = cleanedValue;
            }
        }
        return Object.keys(cleaned).length > 0 ? cleaned : undefined;
    }

    function trackChange(path, value) {
        const existingIndex = state.changes.findIndex(c => c.path === path);
        if (existingIndex >= 0) {
            state.changes[existingIndex].value = value;
        } else {
            state.changes.push({ path, value, timestamp: Date.now() });
        }
    }

    function hasChanged(path) {
        const baselineValue = getNestedValue(jsyaml.load(state.baselineYamlText) || {}, path);
        const currentValue = getNestedValue(state.currentObject, path);
        return JSON.stringify(baselineValue) !== JSON.stringify(currentValue);
    }

    function revertField(path) {
        const baselineObject = jsyaml.load(state.baselineYamlText) || {};
        const baselineValue = getNestedValue(baselineObject, path);
        setNestedValue(state.currentObject, path, baselineValue);
        state.changes = state.changes.filter(c => c.path !== path);
        syncObjectToYaml();
        renderCurrentSection();
    }

    function revertSection() {
        const baselineObject = jsyaml.load(state.baselineYamlText) || {};
        state.currentObject[state.currentSection] = JSON.parse(JSON.stringify(baselineObject[state.currentSection] || {}));
        state.changes = state.changes.filter(c => !c.path.startsWith(state.currentSection));
        syncObjectToYaml();
        renderCurrentSection();
    }

    function revertAll() {
        if (!confirm('Revert all changes to baseline?')) return;
        setYamlText(state.baselineYamlText, false);
        state.changes = [];
        renderCurrentSection();
    }

    function updateValidation() {
        const resultsContainer = document.getElementById('validation-results');
        
        if (!state.schema || !state.currentObject) {
            resultsContainer.innerHTML = '<div class="validation-success">No data to validate</div>';
            state.validationErrors = 0;
            updateHeaderStatus();
            return;
        }

        try {
            const ajv = new window.ajv7({ allErrors: true, strict: false });
            addFormats(ajv);
            
            const schemaForValidation = JSON.parse(JSON.stringify(state.schema));
            delete schemaForValidation.$schema;
            
            const validate = ajv.compile(schemaForValidation);
            const coercedObject = coerceValueBySchema(state.currentObject, schemaForValidation);
            state.currentObject = coercedObject || {};
            const valid = validate(state.currentObject);

            if (valid) {
                resultsContainer.innerHTML = '<div class="validation-success">Validation passed</div>';
                state.validationErrors = 0;
            } else {
                resultsContainer.innerHTML = validate.errors.map(error => `
                    <div class="validation-item">
                        <div class="path">${error.instancePath || '/'}</div>
                        <div class="message">${error.message}</div>
                    </div>
                `).join('');
                state.validationErrors = validate.errors.length;
            }
            updateHeaderStatus();
        } catch (error) {
            resultsContainer.innerHTML = `<div class="validation-item"><div class="message">Validation error: ${error.message}</div></div>`;
            state.validationErrors = 1;
            updateHeaderStatus();
        }
    }

    function addFormats(ajv) {
        ajv.addFormat('ipv4', {
            type: 'string',
            validate: (x) => /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(x)
        });
        ajv.addFormat('cidr', {
            type: 'string',
            validate: (x) => /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(?:[0-9]|[1-2][0-9]|3[0-2])$/.test(x)
        });
        ajv.addFormat('uri', {
            type: 'string',
            validate: (x) => {
                try { new URL(x); return true; } catch { return false; }
            }
        });
        ajv.addFormat('fqdn', {
            type: 'string',
            validate: (x) => /^(?=.{1,253}$)(?:(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)*(?!-)[A-Za-z0-9-]{1,63}(?<!-)$/.test(x)
        });
    }

    function updateChanges() {
        const container = document.getElementById('changes-list');
        
        if (state.changes.length === 0) {
            container.innerHTML = '<div class="validation-success">No changes</div>';
            updateHeaderStatus();
            return;
        }

        container.innerHTML = state.changes.map(change => `
            <div class="change-item">
                <span class="path">${change.path}</span>
                <button class="revert-change" data-path="${change.path}">Revert</button>
            </div>
        `).join('');

        container.querySelectorAll('.revert-change').forEach(btn => {
            btn.addEventListener('click', () => revertField(btn.dataset.path));
        });
        
        updateHeaderStatus();
    }

    function updateHeaderStatus() {
        const filenameEl = document.getElementById('header-filename');
        const changesCountEl = document.getElementById('changes-count');
        const errorsCountEl = document.getElementById('errors-count');
        const changesEl = document.getElementById('header-changes');
        const errorsEl = document.getElementById('header-errors');
        
        if (filenameEl) filenameEl.textContent = state.currentFilename;
        if (changesCountEl) changesCountEl.textContent = state.changes.length;
        if (errorsCountEl) errorsCountEl.textContent = state.validationErrors;
        
        if (changesEl) {
            changesEl.style.display = state.changes.length > 0 ? 'inline-flex' : 'none';
        }
        if (errorsEl) {
            errorsEl.style.display = state.validationErrors > 0 ? 'inline-flex' : 'none';
        }
    }

    function updateDiff() {
        const container = document.getElementById('diff-preview');
        
        if (state.currentYamlText === state.baselineYamlText) {
            container.innerHTML = '<span style="color: #6a6e73;">No changes from baseline</span>';
            return;
        }

        try {
            const diff = Diff.createTwoFilesPatch('baseline.yaml', 'current.yaml', state.baselineYamlText, state.currentYamlText);
            container.innerHTML = formatDiff(diff);
        } catch (error) {
            container.textContent = 'Failed to generate diff';
        }
    }

    function formatDiff(diff) {
        return diff.split('\n').map(line => {
            if (line.startsWith('+') && !line.startsWith('+++')) {
                return `<span class="diff-add">${escapeHtml(line)}</span>`;
            } else if (line.startsWith('-') && !line.startsWith('---')) {
                return `<span class="diff-remove">${escapeHtml(line)}</span>`;
            } else if (line.startsWith('@@')) {
                return `<span class="diff-header">${escapeHtml(line)}</span>`;
            }
            return escapeHtml(line);
        }).join('\n');
    }

    function showParseError(error) {
        const container = document.getElementById('error-results');
        container.innerHTML = `
            <div class="validation-item">
                <div class="path">YAML Parse Error</div>
                <div class="message">${escapeHtml(error.message)}</div>
            </div>
        `;
    }

    function clearParseError() {
        const container = document.getElementById('error-results');
        container.innerHTML = '<div class="validation-success">No errors</div>';
    }

    function showError(message) {
        const container = document.getElementById('error-results');
        container.innerHTML = `
            <div class="validation-item">
                <div class="message">${escapeHtml(message)}</div>
            </div>
        `;
    }

    function handleHelpHover(e) {
        if (state.pinnedHelp) return;
        
        if (state.helpHideTimeout) {
            clearTimeout(state.helpHideTimeout);
            state.helpHideTimeout = null;
        }
        
        const target = e.currentTarget;
        state.helpTimeout = setTimeout(() => {
            showHelpBubble(target);
        }, 300);
    }

    function handleHelpLeave() {
        if (state.helpTimeout) {
            clearTimeout(state.helpTimeout);
            state.helpTimeout = null;
        }
        if (!state.pinnedHelp) {
            state.helpHideTimeout = setTimeout(() => {
                hideHelpBubble();
            }, 400);
        }
    }
    
    function handleBubbleEnter() {
        if (state.helpHideTimeout) {
            clearTimeout(state.helpHideTimeout);
            state.helpHideTimeout = null;
        }
    }
    
    function handleBubbleLeave() {
        if (!state.pinnedHelp) {
            state.helpHideTimeout = setTimeout(() => {
                hideHelpBubble();
            }, 400);
        }
    }

    function showHelpBubble(target) {
        const bubble = document.getElementById('help-bubble');
        const description = target.dataset.description;
        const docUrl = target.dataset.docUrl;

        document.getElementById('help-description').textContent = description || 'No description available';
        
        const linksContainer = document.getElementById('help-links');
        linksContainer.innerHTML = '';
        if (docUrl && docUrl !== 'undefined') {
            try {
                const urls = JSON.parse(docUrl);
                if (typeof urls === 'object') {
                    Object.entries(urls).forEach(([label, url]) => {
                        const link = document.createElement('a');
                        link.href = url;
                        link.target = '_blank';
                        link.textContent = label;
                        link.style.display = 'block';
                        link.style.marginTop = '4px';
                        linksContainer.appendChild(link);
                    });
                }
            } catch {
                if (docUrl.startsWith('http')) {
                    const link = document.createElement('a');
                    link.href = docUrl;
                    link.target = '_blank';
                    link.textContent = 'Documentation';
                    linksContainer.appendChild(link);
                }
            }
        }

        bubble.style.visibility = 'hidden';
        bubble.style.display = 'block';
        bubble.style.left = '0px';
        bubble.style.top = '0px';
        
        const bubbleWidth = bubble.offsetWidth;
        const bubbleHeight = bubble.offsetHeight;
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;
        
        const rect = target.getBoundingClientRect();
        let left = rect.right + 10;
        let top = rect.top;
        
        if (left + bubbleWidth > viewportWidth - 10) {
            left = rect.left - bubbleWidth - 10;
        }
        if (left < 10) left = 10;
        if (top + bubbleHeight > viewportHeight - 10) {
            top = viewportHeight - bubbleHeight - 10;
        }
        if (top < 10) top = 10;
        
        bubble.style.left = `${left}px`;
        bubble.style.top = `${top}px`;
        bubble.style.visibility = 'visible';
    }

    function hideHelpBubble() {
        if (state.pinnedHelp) return;
        document.getElementById('help-bubble').style.display = 'none';
    }

    function forceHideHelpBubble() {
        state.pinnedHelp = false;
        document.getElementById('help-bubble').style.display = 'none';
        updatePinButtonIcon();
    }

    function togglePinHelp() {
        state.pinnedHelp = !state.pinnedHelp;
        updatePinButtonIcon();
    }

    function updatePinButtonIcon() {
        const pinBtn = document.querySelector('.help-bubble-pin');
        if (state.pinnedHelp) {
            pinBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M16 9V4l1 0c.55 0 1-.45 1-1s-.45-1-1-1H7c-.55 0-1 .45-1 1s.45 1 1 1l1 0v5c0 1.66-1.34 3-3 3v2h5.97v7l1 1 1-1v-7H19v-2c-1.66 0-3-1.34-3-3z"/></svg>';
            pinBtn.title = 'Unpin';
        } else {
            pinBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M14 4v5c0 1.12.37 2.16 1 3H9c.65-.86 1-1.9 1-3V4h4m3-2H7c-.55 0-1 .45-1 1s.45 1 1 1h1v5c0 1.66-1.34 3-3 3v2h5.97v7l1 1 1-1v-7H19v-2c-1.66 0-3-1.34-3-3V4h1c.55 0 1-.45 1-1s-.45-1-1-1z"/></svg>';
            pinBtn.title = 'Pin';
        }
    }

    function newDocument() {
        if (!confirm('Create new document? Unsaved changes will be lost.')) return;
        setYamlText(getDefaultYaml(), true);
    }

    function handleFileLoad(e) {
        const file = e.target.files[0];
        if (!file) return;

        const validExtensions = ['.yaml', '.yml', '.clusterfile'];
        const fileName = file.name.toLowerCase();
        const hasValidExtension = validExtensions.some(ext => fileName.endsWith(ext));
        
        if (!hasValidExtension) {
            showError('Invalid file type. Please select a .yaml, .yml, or .clusterfile file.');
            e.target.value = '';
            return;
        }

        const reader = new FileReader();
        reader.onload = (event) => {
            setYamlText(event.target.result, true);
            state.currentFilename = file.name;
            updateHeaderStatus();
        };
        reader.readAsText(file);
        e.target.value = '';
    }

    function saveToLocalStorage() {
        const yamlToSave = redactSecrets(buildNormalizedYaml());
        localStorage.setItem(STORAGE_KEYS.LAST_YAML, yamlToSave);
        alert('Saved to browser storage');
    }

    function redactSecrets(yaml) {
        return yaml;
    }

    function downloadYaml() {
        const normalizedYaml = buildNormalizedYaml();
        const blob = new Blob([normalizedYaml], { type: 'text/yaml' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'clusterfile.yaml';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    function formatYaml() {
        try {
            const formatted = buildNormalizedYaml({ preserveCurrentText: true });
            state.editor.setValue(formatted);
        } catch (error) {
            showError('Failed to format YAML: ' + error.message);
        }
    }

    function copyYaml() {
        const normalizedYaml = buildNormalizedYaml();
        navigator.clipboard.writeText(normalizedYaml).then(() => {
            alert('Copied to clipboard');
        }).catch(() => {
            showError('Failed to copy to clipboard');
        });
    }

    function parsePath(path) {
        if (!path) return [];
        const parts = [];
        let i = 0;
        while (i < path.length) {
            if (path[i] === '[') {
                const closeBracket = path.indexOf(']', i);
                if (closeBracket === -1) break;
                let key = path.substring(i + 1, closeBracket);
                if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
                    key = key.slice(1, -1);
                }
                parts.push(key);
                i = closeBracket + 1;
                if (path[i] === '.') i++;
            } else {
                let nextDot = path.indexOf('.', i);
                let nextBracket = path.indexOf('[', i);
                let end = path.length;
                if (nextDot !== -1 && (nextBracket === -1 || nextDot < nextBracket)) {
                    end = nextDot;
                } else if (nextBracket !== -1) {
                    end = nextBracket;
                }
                if (end > i) {
                    parts.push(path.substring(i, end));
                }
                i = end;
                if (path[i] === '.') i++;
            }
        }
        return parts;
    }

    function buildHostPath(hostname) {
        if (hostname.includes('.') || hostname.includes('[') || hostname.includes(']')) {
            return `hosts["${hostname}"]`;
        }
        return `hosts.${hostname}`;
    }

    function getHostnameFromPath(path) {
        const match = path.match(/^hosts\["([^"]+)"\]/);
        if (match) return match[1];
        const match2 = path.match(/^hosts\.([^.]+)/);
        if (match2) return match2[1];
        return null;
    }

    function getNestedValue(obj, path) {
        if (!path) return obj;
        const parts = parsePath(path);
        let current = obj;
        for (const part of parts) {
            if (current === null || current === undefined) return undefined;
            current = current[part];
        }
        return current;
    }

    function setNestedValue(obj, path, value) {
        if (!path) return;
        const parts = parsePath(path);
        let current = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            const part = parts[i];
            const nextPart = parts[i + 1];
            if (current[part] === undefined || current[part] === null) {
                current[part] = /^\d+$/.test(nextPart) ? [] : {};
            }
            current = current[part];
        }
        const lastPart = parts[parts.length - 1];
        if (value === undefined) {
            delete current[lastPart];
        } else {
            current[lastPart] = value;
        }
    }

    function coerceValueBySchema(value, schema) {
        if (value === null || value === undefined || !schema) return value;

        const composite = schema.anyOf || schema.oneOf;
        if (composite && Array.isArray(composite)) {
            const numberOption = composite.find(o => o.type === 'integer' || o.type === 'number');
            if (numberOption && typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) {
                return numberOption.type === 'integer' ? parseInt(value, 10) : Number(value);
            }
            const booleanOption = composite.find(o => o.type === 'boolean');
            if (booleanOption && typeof value === 'string') {
                if (value === 'true') return true;
                if (value === 'false') return false;
            }
            const objectOption = composite.find(o => o.type === 'object' || o.properties || o.patternProperties);
            if (objectOption && typeof value === 'object' && !Array.isArray(value)) {
                return coerceObjectBySchema(value, objectOption);
            }
            const arrayOption = composite.find(o => o.type === 'array' || o.items);
            if (arrayOption && Array.isArray(value)) {
                const itemSchema = arrayOption.items || {};
                return value.map(item => coerceValueBySchema(item, itemSchema));
            }
        }

        if (schema.type === 'integer' || schema.type === 'number') {
            if (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) {
                return schema.type === 'integer' ? parseInt(value, 10) : Number(value);
            }
            return value;
        }

        if (schema.type === 'boolean') {
            if (typeof value === 'string') {
                if (value === 'true') return true;
                if (value === 'false') return false;
            }
            return value;
        }

        if (schema.type === 'array' && Array.isArray(value)) {
            const itemSchema = schema.items || {};
            return value.map(item => coerceValueBySchema(item, itemSchema));
        }

        if ((schema.type === 'object' || schema.properties || schema.patternProperties) &&
            typeof value === 'object' && value !== null && !Array.isArray(value)) {
            return coerceObjectBySchema(value, schema);
        }

        return value;
    }

    function coerceObjectBySchema(obj, schema) {
        const props = schema.properties || {};
        const patternProps = schema.patternProperties || {};
        const additional = schema.additionalProperties;

        const result = Array.isArray(obj) ? [] : {};
        Object.entries(obj).forEach(([key, val]) => {
            let childSchema = props[key];
            if (!childSchema && patternProps && Object.keys(patternProps).length > 0) {
                for (const [pattern, patternSchema] of Object.entries(patternProps)) {
                    const regex = new RegExp(pattern);
                    if (regex.test(key)) {
                        childSchema = patternSchema;
                        break;
                    }
                }
            }
            if (!childSchema && additional && typeof additional === 'object') {
                childSchema = additional;
            }
            result[key] = childSchema ? coerceValueBySchema(val, childSchema) : val;
        });

        return result;
    }

    function buildNormalizedYaml(options = {}) {
        const sourceObject = options.preserveCurrentText
            ? (jsyaml.load(state.currentYamlText) || {})
            : state.currentObject;
        const coercedObject = state.schema
            ? coerceValueBySchema(sourceObject, state.schema)
            : sourceObject;
        const baselineObject = jsyaml.load(state.baselineYamlText) || {};
        const cleanedObject = cleanObject(coercedObject, baselineObject);
        return jsyaml.dump(cleanedObject, {
            indent: 2,
            lineWidth: -1,
            noRefs: true,
            sortKeys: false
        });
    }

    function getDocUrl(schema) {
        if (!schema) return '';
        const docUrl = schema['x-doc-url'] || schema['x-doc-urls'];
        if (!docUrl) return '';
        if (typeof docUrl === 'string') return docUrl;
        if (Array.isArray(docUrl)) {
            if (typeof docUrl[0] === 'string') return docUrl[0];
            if (typeof docUrl[0] === 'object') return JSON.stringify(docUrl[0]);
        }
        if (typeof docUrl === 'object') return JSON.stringify(docUrl);
        return '';
    }

    function capitalizeFirst(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    function escapeHtml(str) {
        if (!str) return '';
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function debounce(fn, delay) {
        let timeout;
        return function(...args) {
            clearTimeout(timeout);
            timeout = setTimeout(() => fn.apply(this, args), delay);
        };
    }

    async function loadTemplates() {
        try {
            const response = await fetch(getApiBase() + '/api/templates');
            const data = await response.json();
            templateState.templates = data.templates || [];
            
            const select = document.getElementById('template-select');
            select.innerHTML = '<option value="">-- Select a template --</option>';
            
            templateState.templates.forEach(template => {
                const option = document.createElement('option');
                option.value = template.name;
                option.textContent = template.name;
                option.dataset.description = template.description || '';
                select.appendChild(option);
            });
        } catch (error) {
            console.error('Failed to load templates:', error);
        }
    }

    function initTemplateOutputEditor() {
        const editorElement = document.getElementById('template-output-editor');
        if (!editorElement) return;
        
        templateState.outputEditor = CodeMirror(editorElement, {
            mode: 'yaml',
            theme: 'default',
            lineNumbers: true,
            lineWrapping: true,
            readOnly: true,
            tabSize: 2
        });
    }

    function initTemplateEventListeners() {
        const templateSelect = document.getElementById('template-select');
        if (templateSelect) {
            templateSelect.addEventListener('change', handleTemplateSelect);
        }

        const addParamBtn = document.getElementById('add-param-btn');
        if (addParamBtn) {
            addParamBtn.addEventListener('click', addParamRow);
        }

        const paramsContainer = document.getElementById('params-container');
        if (paramsContainer) {
            paramsContainer.addEventListener('click', (e) => {
                if (e.target.classList.contains('remove-param-btn')) {
                    removeParamRow(e.target);
                }
            });
        }

        const renderBtn = document.getElementById('btn-render');
        if (renderBtn) {
            renderBtn.addEventListener('click', renderTemplate);
        }

        const previewBtn = document.getElementById('btn-preview-template');
        if (previewBtn) {
            previewBtn.addEventListener('click', previewTemplateSource);
        }

        const copyOutputBtn = document.getElementById('btn-copy-output');
        if (copyOutputBtn) {
            copyOutputBtn.addEventListener('click', copyTemplateOutput);
        }

        const downloadOutputBtn = document.getElementById('btn-download-output');
        if (downloadOutputBtn) {
            downloadOutputBtn.addEventListener('click', downloadTemplateOutput);
        }
    }

    function handleTemplateSelect(e) {
        const selectedOption = e.target.selectedOptions[0];
        const descriptionEl = document.getElementById('template-description');
        if (selectedOption && selectedOption.dataset.description) {
            descriptionEl.textContent = selectedOption.dataset.description;
        } else {
            descriptionEl.textContent = '';
        }
    }

    function addParamRow() {
        const container = document.getElementById('params-container');
        const row = document.createElement('div');
        row.className = 'param-row';
        row.innerHTML = `
            <input type="text" class="param-path" placeholder="$.hosts[*].bmc.username" title="JSONPath expression">
            <input type="text" class="param-value" placeholder="new-value" title="Value to set">
            <button class="remove-param-btn pf-c-button pf-m-plain" type="button" title="Remove">X</button>
        `;
        container.appendChild(row);
    }

    function removeParamRow(btn) {
        const row = btn.closest('.param-row');
        const container = document.getElementById('params-container');
        if (container.querySelectorAll('.param-row').length > 1) {
            row.remove();
        } else {
            row.querySelector('.param-path').value = '';
            row.querySelector('.param-value').value = '';
        }
    }

    function getParams() {
        const params = [];
        const rows = document.querySelectorAll('#params-container .param-row');
        rows.forEach(row => {
            const path = row.querySelector('.param-path').value.trim();
            const value = row.querySelector('.param-value').value;
            if (path && value !== undefined && value !== '') {
                params.push(`${path}=${value}`);
            }
        });
        return params;
    }

    async function renderTemplate() {
        const templateName = document.getElementById('template-select').value;
        if (!templateName) {
            alert('Please select a template');
            return;
        }

        const yamlText = state.currentYamlText;
        if (!yamlText || yamlText.trim() === '') {
            alert('Please load or create a clusterfile first');
            return;
        }

        const params = getParams();

        try {
            const response = await fetch(getApiBase() + '/api/render', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    yaml_text: yamlText,
                    template_name: templateName,
                    params: params
                })
            });

            const result = await response.json();

            if (!response.ok) {
                showTemplateError(result.detail || 'Rendering failed');
                return;
            }

            if (result.success) {
                templateState.lastRenderedOutput = result.output;
                templateState.outputEditor.setValue(result.output);
                
                const outputContainer = document.querySelector('.template-output');
                outputContainer.style.display = 'block';
                
                const warningsEl = document.getElementById('template-warnings');
                if (result.warnings && result.warnings.length > 0) {
                    warningsEl.innerHTML = '<strong>Warnings:</strong><br>' + result.warnings.join('<br>');
                } else {
                    warningsEl.innerHTML = '';
                }
                
                clearTemplateError();
            } else {
                showTemplateError(result.error || 'Rendering failed');
            }
        } catch (error) {
            console.error('Failed to render template:', error);
            showTemplateError('Failed to render template: ' + error.message);
        }
    }

    async function previewTemplateSource() {
        const templateName = document.getElementById('template-select').value;
        if (!templateName) {
            alert('Please select a template');
            return;
        }

        try {
            const response = await fetch(getApiBase() + `/api/templates/${templateName}`);
            const result = await response.json();

            if (response.ok) {
                templateState.lastRenderedOutput = result.content;
                templateState.outputEditor.setValue(result.content);
                
                const outputContainer = document.querySelector('.template-output');
                outputContainer.style.display = 'block';
                
                document.getElementById('template-warnings').innerHTML = '<em>Showing template source (not rendered output)</em>';
            } else {
                showTemplateError(result.detail || 'Failed to load template');
            }
        } catch (error) {
            console.error('Failed to preview template:', error);
            showTemplateError('Failed to preview template: ' + error.message);
        }
    }

    function showTemplateError(message) {
        let errorEl = document.querySelector('.template-error');
        if (!errorEl) {
            errorEl = document.createElement('div');
            errorEl.className = 'template-error';
            const form = document.querySelector('.template-form');
            form.parentNode.insertBefore(errorEl, form);
        }
        errorEl.textContent = message;
        errorEl.style.display = 'block';
    }

    function clearTemplateError() {
        const errorEl = document.querySelector('.template-error');
        if (errorEl) {
            errorEl.style.display = 'none';
        }
    }

    function copyTemplateOutput() {
        const output = templateState.lastRenderedOutput;
        if (output) {
            navigator.clipboard.writeText(output).then(() => {
                const btn = document.getElementById('btn-copy-output');
                const originalText = btn.textContent;
                btn.textContent = 'Copied!';
                setTimeout(() => btn.textContent = originalText, 1500);
            });
        }
    }

    function downloadTemplateOutput() {
        const output = templateState.lastRenderedOutput;
        if (!output) return;

        const templateName = document.getElementById('template-select').value;
        let filename = templateName.replace('.tpl', '').replace('.tmpl', '');
        if (!filename.endsWith('.yaml') && !filename.endsWith('.yml') && !filename.endsWith('.sh')) {
            filename += '.yaml';
        }

        const blob = new Blob([output], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    document.addEventListener('DOMContentLoaded', init);
})();
