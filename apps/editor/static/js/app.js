(function() {
    'use strict';

    const STORAGE_KEYS = {
        LAST_YAML: 'CLUSTERFILE_LAST_YAML',
        UPLOADED_SCHEMA: 'CLUSTERFILE_UPLOADED_SCHEMA',
        TOUR_SHOWN: 'CLUSTERFILE_TOUR_SHOWN',
        MODE: 'CLUSTERFILE_MODE',
        LAST_SECTION_BY_FILE: 'CLUSTERFILE_LAST_SECTION_BY_FILE',
        LAST_FILENAME: 'CLUSTERFILE_LAST_FILENAME',
        LAST_EDITOR_VIEW: 'CLUSTERFILE_LAST_EDITOR_VIEW',
        DEMO_SHOWN: 'CLUSTERFILE_DEMO_SHOWN',
        THEME: 'CLUSTERFILE_THEME'
    };

    let templateState = {
        templates: [],
        outputEditor: null,
        lastRenderedOutput: '',
        lastTemplateSource: '',
        lastTemplateName: '',
        outputView: 'rendered',
        lastRenderedInput: '',
        rendering: false
    };

    let demoState = {
        active: false,
        canceled: false,
        highlights: [],
        outputMarks: []
    };

    const SENSITIVE_FIELDS = ['pullSecret', 'password', 'secret'];
    const FILE_SECTIONS = ['account', 'cluster', 'network', 'hosts', 'plugins'];
    const EDITOR_VIEWS = {
        CLUSTERFILE: 'clusterfile',
        TEMPLATES: 'templates'
    };

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
        helpTarget: null,
        currentFilename: 'untitled',
        validationErrors: 0,
        samples: [],
        lastSavedYaml: null,
        editorView: EDITOR_VIEWS.CLUSTERFILE,
        currentTab: 'validation'
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
        startDemoIfNeeded();
        initDevReload();
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
        document.querySelectorAll('.pf-v6-c-nav__link[data-section]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                switchSection(link.dataset.section);
            });
        });
        document.querySelectorAll('.pf-v6-c-nav__link[data-template-view]').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                setEditorMode(EDITOR_VIEWS.TEMPLATES);
                setTemplateOutputView(link.dataset.templateView);
            });
        });

        document.querySelectorAll('.nav-group-toggle[data-menu]').forEach(btn => {
            btn.addEventListener('click', () => toggleNavGroup(btn.dataset.menu));
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

        document.querySelectorAll('.pf-v6-c-tabs__link[data-tab]').forEach(tab => {
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
        const navReplay = document.getElementById('nav-replay-demo');
        if (navReplay) navReplay.addEventListener('click', replayDemo);
        const aboutChangelog = document.getElementById('about-changelog');
        if (aboutChangelog) aboutChangelog.addEventListener('click', () => switchSection('changelog'));
        const aboutReplay = document.getElementById('about-replay');
        if (aboutReplay) aboutReplay.addEventListener('click', replayDemo);
        const paramsToggle = document.getElementById('toggle-params');
        if (paramsToggle) paramsToggle.addEventListener('click', toggleParamsPanel);
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.addEventListener('change', (e) => {
                setTheme(e.target.checked ? 'dark' : 'light');
            });
        }

        document.querySelectorAll('.editor-toggle-btn').forEach(btn => {
            btn.addEventListener('click', () => handleEditorToggle(btn.dataset.editorView));
        });
        
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
        window.addEventListener('resize', handleHelpReposition);
        window.addEventListener('scroll', handleHelpReposition, true);
    }

    function loadSavedState() {
        const savedTheme = localStorage.getItem(STORAGE_KEYS.THEME) || 'light';
        setTheme(savedTheme);
        const savedMode = localStorage.getItem(STORAGE_KEYS.MODE);
        if (savedMode) {
            setMode(savedMode);
            const modeToggle = document.getElementById('mode-toggle');
            if (modeToggle) {
                modeToggle.value = savedMode;
            }
        }

        const savedFilename = localStorage.getItem(STORAGE_KEYS.LAST_FILENAME);
        if (savedFilename) {
            state.currentFilename = savedFilename;
        }

        const savedYaml = localStorage.getItem(STORAGE_KEYS.LAST_YAML);
        if (savedYaml) {
            setYamlText(savedYaml, true);
            state.lastSavedYaml = savedYaml;
        } else {
            setYamlText(getDefaultYaml(), true);
            state.lastSavedYaml = null;
        }
        const savedEditorView = localStorage.getItem(STORAGE_KEYS.LAST_EDITOR_VIEW);
        if (savedEditorView && Object.values(EDITOR_VIEWS).includes(savedEditorView)) {
            setEditorView(savedEditorView);
        } else {
            setEditorView(EDITOR_VIEWS.CLUSTERFILE);
        }
        restoreSectionForFile();
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
        startDemoIfNeeded();
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

    function startDemoIfNeeded() {
        if (demoState.active) return;
        if (localStorage.getItem(STORAGE_KEYS.DEMO_SHOWN)) return;
        const tourModal = document.getElementById('tour-modal');
        if (tourModal && tourModal.style.display === 'block') return;
        runDemoSequence().catch(() => {
            stopDemo();
        });
    }

    function replayDemo() {
        if (demoState.active) {
            stopDemo();
        }
        localStorage.removeItem(STORAGE_KEYS.DEMO_SHOWN);
        runDemoSequence().catch(() => {
            stopDemo();
        });
    }

    function stopDemo() {
        demoState.canceled = true;
        demoState.active = false;
        clearHighlights();
        clearOutputHighlights();
        hideDemoBanner();
        localStorage.setItem(STORAGE_KEYS.DEMO_SHOWN, 'true');
    }

    function showDemoBanner(text) {
        const banner = document.getElementById('demo-banner');
        const textEl = document.getElementById('demo-text');
        if (!banner || !textEl) return;
        textEl.textContent = text;
        banner.style.display = 'flex';
    }

    function showToast(message, type = 'info') {
        const toast = document.getElementById('toast');
        const toastText = document.getElementById('toast-text');
        if (!toast) return;
        if (toastText) {
            toastText.textContent = message;
        } else {
            toast.textContent = message;
        }
        toast.classList.remove('pf-m-info', 'pf-m-danger');
        toast.classList.add(type === 'error' ? 'pf-m-danger' : 'pf-m-info');
        toast.style.display = 'block';
        clearTimeout(toast._hideTimer);
        toast._hideTimer = setTimeout(() => {
            toast.style.display = 'none';
        }, 3000);
    }

    function hideDemoBanner() {
        const banner = document.getElementById('demo-banner');
        if (banner) banner.style.display = 'none';
    }

    function highlightElement(el) {
        if (!el) return;
        el.classList.add('demo-highlight');
        demoState.highlights.push(el);
        if (el.scrollIntoView) {
            el.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
    }

    function clearHighlights() {
        demoState.highlights.forEach(el => el.classList.remove('demo-highlight'));
        demoState.highlights = [];
    }

    function clearOutputHighlights() {
        demoState.outputMarks.forEach(mark => mark.clear());
        demoState.outputMarks = [];
    }

    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    function stepDelay(multiplier = 1) {
        return sleep(2000 * multiplier);
    }

    async function runDemoSequence() {
        demoState.active = true;
        demoState.canceled = false;

        const skipBtn = document.getElementById('demo-skip');
        if (skipBtn) skipBtn.addEventListener('click', stopDemo, { once: true });

        showDemoBanner('Loading a sample clusterfile...');
        const samplesSelect = document.getElementById('samples-select');
        highlightElement(samplesSelect);
        if (state.samples.length > 0) {
            await loadSample(state.samples[0].filename);
        }
        await stepDelay(1.2);
        clearHighlights();

        const sections = ['account', 'cluster', 'network', 'hosts', 'plugins'];
        for (const section of sections) {
            if (demoState.canceled) return;
            showDemoBanner(`Browsing ${capitalizeFirst(section)} settings...`);
            const link = document.querySelector(`.pf-v6-c-nav__link[data-section="${section}"]`);
            highlightElement(link);
            switchSection(section);
            highlightElement(document.getElementById('form-pane'));
            await stepDelay(1.1);
            clearHighlights();
        }

        if (demoState.canceled) return;
        showDemoBanner('Rendering a template...');
        switchSection('templates');
        const templateSelect = document.getElementById('template-select');
        const renderBtn = document.getElementById('btn-render');
        if (templateSelect && templateState.templates.length > 0) {
            templateSelect.value = templateState.templates[0].name;
            handleTemplateSelect({ target: templateSelect });
            highlightElement(templateSelect);
            highlightElement(renderBtn);
            await renderTemplate();
            highlightElement(document.getElementById('template-output-pane'));
            await stepDelay(1.1);
        }
        clearHighlights();

        if (demoState.canceled) return;
        const originalName = getNestedValue(state.currentObject, 'cluster.name');
        const demoName = originalName ? `${originalName}-demo` : 'demo-cluster';
        showDemoBanner('Making a change...');
        switchSection('cluster');
        updateFieldValue('cluster.name', demoName);
        const changesBadge = document.getElementById('header-changes');
        highlightElement(changesBadge);
        switchTab('changes');
        highlightElement(document.getElementById('changes-list'));
        await stepDelay(1.3);
        clearHighlights();

        if (demoState.canceled) return;
        showDemoBanner('Re-rendering with the change...');
        switchSection('templates');
        await renderTemplate();
        highlightElement(document.getElementById('template-output-pane'));
        highlightTemplateOutput(demoName);
        await stepDelay(1.6);
        clearOutputHighlights();

        showDemoBanner('Demo complete. Ready to edit your own clusterfile.');
        await stepDelay(1.0);

        resetToBaseline();
        hideDemoBanner();
        demoState.active = false;
        localStorage.setItem(STORAGE_KEYS.DEMO_SHOWN, 'true');
    }

    function highlightTemplateOutput(value) {
        if (!templateState.outputEditor || !value) return;
        clearOutputHighlights();
        const doc = templateState.outputEditor.getDoc();
        const text = doc.getValue();
        let index = 0;
        while (index !== -1) {
            index = text.indexOf(value, index);
            if (index === -1) break;
            const from = doc.posFromIndex(index);
            const to = doc.posFromIndex(index + value.length);
            const mark = doc.markText(from, to, { className: 'demo-output-highlight' });
            demoState.outputMarks.push(mark);
            index += value.length;
        }
    }

    function resetToBaseline() {
        const baselineObject = jsyaml.load(state.baselineYamlText) || {};
        state.currentObject = JSON.parse(JSON.stringify(baselineObject));
        state.changes = [];
        syncObjectToYaml();
        renderCurrentSection();
        updateChanges();
    }

    function setMode(mode) {
        state.mode = mode;
        localStorage.setItem(STORAGE_KEYS.MODE, mode);
        document.body.classList.remove('guided-mode', 'advanced-mode');
        document.body.classList.add(mode + '-mode');
    }

    function switchSection(section, options = {}) {
        const { fromEditor = false } = options;
        state.currentSection = section;
        document.querySelectorAll('.pf-v6-c-nav__link[data-section]').forEach(link => {
            link.classList.toggle('pf-m-current', link.dataset.section === section);
        });
        document.getElementById('section-title').textContent = capitalizeFirst(section);
        updateSectionDescription(section);
        updateNavGroupCurrent(section);
        if (FILE_SECTIONS.includes(section)) {
            rememberSectionForFile(section);
        }
        
        const formContainer = document.getElementById('form-container');
        const templatesContainer = document.getElementById('templates-container');
        const changelogContainer = document.getElementById('changelog-container');
        const aboutContainer = document.getElementById('about-container');
        const editorPane = document.getElementById('editor-pane');
        const yamlEditorContainer = document.querySelector('.yaml-editor-container');
        const templateOutputPane = document.getElementById('template-output-pane');
        const tabsContainer = document.querySelector('.tabs-container');
        const formActions = document.querySelector('.form-actions');

        if (section === 'templates') {
            formContainer.style.display = 'none';
            templatesContainer.style.display = 'block';
            if (changelogContainer) changelogContainer.style.display = 'none';
            if (aboutContainer) aboutContainer.style.display = 'none';
            editorPane.style.display = 'flex';
            const templateSelect = document.getElementById('template-select');
            if (templateSelect && !templateSelect.value && templateState.templates.length > 0) {
                templateSelect.value = templateState.templates[0].name;
                handleTemplateSelect({ target: templateSelect });
            }
            if (!fromEditor) {
                setEditorMode(EDITOR_VIEWS.TEMPLATES, { fromSection: true });
            }
            if (formActions) formActions.style.display = 'none';
        } else if (section === 'changelog') {
            formContainer.style.display = 'none';
            templatesContainer.style.display = 'none';
            if (changelogContainer) changelogContainer.style.display = 'block';
            if (aboutContainer) aboutContainer.style.display = 'none';
            editorPane.style.display = 'none';
            if (formActions) formActions.style.display = 'none';
            loadChangelog();
        } else if (section === 'about') {
            formContainer.style.display = 'none';
            templatesContainer.style.display = 'none';
            if (changelogContainer) changelogContainer.style.display = 'none';
            if (aboutContainer) aboutContainer.style.display = 'block';
            editorPane.style.display = 'none';
            if (formActions) formActions.style.display = 'none';
        } else {
            formContainer.style.display = 'block';
            templatesContainer.style.display = 'none';
            if (changelogContainer) changelogContainer.style.display = 'none';
            if (aboutContainer) aboutContainer.style.display = 'none';
            editorPane.style.display = 'flex';
            if (!fromEditor) {
                setEditorMode(EDITOR_VIEWS.CLUSTERFILE, { fromSection: true });
            }
            if (formActions) formActions.style.display = 'flex';
            renderCurrentSection();
        }
    }

    function switchTab(tab) {
        state.currentTab = tab;
        const tabsContainer = document.querySelector('.tabs-container');
        if (!tabsContainer) return;
        tabsContainer.querySelectorAll('.pf-v6-c-tabs__item').forEach(item => {
            const isCurrent = item.querySelector('.pf-v6-c-tabs__link').dataset.tab === tab;
            item.classList.toggle('pf-m-current', isCurrent);
            item.querySelector('.pf-v6-c-tabs__link').setAttribute('aria-selected', isCurrent ? 'true' : 'false');
        });
        tabsContainer.querySelectorAll('.tab-panel').forEach(panel => {
            panel.hidden = panel.id !== 'panel-' + tab;
        });
    }

    async function loadSample(filename) {
        try {
            const response = await fetch(getApiBase() + `/api/samples/${filename}`);
            const data = await response.json();
            setYamlText(data.content, true);
            setCurrentFilename(filename);
            markUnsaved();
            restoreSectionForFile();
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
        container.classList.add('pf-v6-c-form', 'pf-m-horizontal');
        updateSectionDescription(state.currentSection);

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
        container.classList.add('pf-v6-c-form', 'pf-m-horizontal');

        Object.entries(schema.properties).forEach(([key, propSchema]) => {
            const fieldPath = path ? `${path}.${key}` : key;
            const value = data ? data[key] : undefined;
            renderField(container, key, propSchema, value, fieldPath);
        });
    }

    function renderField(container, key, schema, value, path) {
        const group = document.createElement('div');
        group.className = 'pf-v6-c-form__group';
        group.dataset.path = path;

        const fieldId = `field-${path.replace(/[^a-z0-9]/gi, '-')}`;

        const labelWrapper = document.createElement('div');
        labelWrapper.className = 'pf-v6-c-form__group-label pf-v6-l-flex pf-m-align-items-center pf-m-space-items-sm';

        const label = document.createElement('label');
        label.className = 'pf-v6-c-form__label';
        label.htmlFor = fieldId;
        const labelText = document.createElement('span');
        labelText.className = 'pf-v6-c-form__label-text';
        labelText.textContent = schema.title || capitalizeFirst(key);
        label.appendChild(labelText);

        const helpButton = document.createElement('button');
        helpButton.type = 'button';
        helpButton.className = 'pf-v6-c-button pf-m-plain pf-m-icon';
        helpButton.setAttribute('aria-label', 'Field information');
        helpButton.innerHTML = `
            <span class="pf-v6-c-button__icon">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                </svg>
            </span>
        `;
        helpButton.dataset.description = schema.description || '';
        helpButton.dataset.docUrl = getDocUrl(schema);
        if (!helpButton.dataset.description && !helpButton.dataset.docUrl) {
            helpButton.hidden = true;
        }
        helpButton.addEventListener('mouseenter', handleHelpHover);
        helpButton.addEventListener('mouseleave', handleHelpLeave);
        helpButton.addEventListener('focus', handleHelpFocus);
        helpButton.addEventListener('blur', handleHelpBlur);
        helpButton.addEventListener('click', handleHelpClick);
        helpButton.addEventListener('mousedown', (e) => { e.stopPropagation(); e.preventDefault(); });
        labelWrapper.appendChild(label);
        labelWrapper.appendChild(helpButton);

        const revertBtn = document.createElement('button');
        revertBtn.type = 'button';
        revertBtn.className = 'pf-v6-c-button pf-m-plain pf-m-small revert-btn';
        revertBtn.innerHTML = '&#x2715;';
        revertBtn.setAttribute('aria-label', 'Revert field');
        revertBtn.title = 'Revert to original value';
        revertBtn.dataset.path = path;
        revertBtn.disabled = !hasChanged(path);
        revertBtn.addEventListener('click', (e) => { e.stopPropagation(); revertField(e.target.dataset.path); });
        labelWrapper.appendChild(revertBtn);

        group.appendChild(labelWrapper);

        const control = document.createElement('div');
        control.className = 'pf-v6-c-form__group-control';
        group.appendChild(control);

        const isComplex = schema['x-is-file'] ||
            schema.type === 'array' ||
            Array.isArray(value) ||
            schema.anyOf ||
            schema.oneOf ||
            schema.type === 'object' ||
            (value !== null && typeof value === 'object' && !Array.isArray(value));

        const controlRow = document.createElement('div');
        controlRow.className = 'pf-v6-l-flex pf-m-align-items-center pf-m-space-items-sm';
        if (!isComplex) {
            control.appendChild(controlRow);
        }

        if (schema['x-is-file']) {
            renderFileField(control, key, schema, value, path, fieldId);
        } else if (schema.type === 'array' || Array.isArray(value)) {
            renderArrayField(control, key, schema, value, path);
        } else if (schema.anyOf || schema.oneOf) {
            renderAnyOfField(control, key, schema, value, path);
        } else if (schema.type === 'object' || (value !== null && typeof value === 'object' && !Array.isArray(value))) {
            renderNestedObjectField(control, key, schema, value, path);
        } else if (schema.enum) {
            renderEnumField(controlRow, key, schema, value, path, fieldId);
        } else if (schema.type === 'boolean') {
            renderBooleanField(controlRow, key, schema, value, path, fieldId);
        } else if (schema.type === 'integer' || schema.type === 'number') {
            renderNumberField(controlRow, key, schema, value, path, fieldId);
        } else {
            renderTextField(controlRow, key, schema, value, path, fieldId);
        }

        if (schema.description) {
            const desc = document.createElement('div');
            desc.className = 'pf-v6-c-form__helper-text';
            desc.textContent = schema.description.substring(0, 100) + (schema.description.length > 100 ? '...' : '');
            control.appendChild(desc);
        }

        container.appendChild(group);
    }

    function createTrashButton(label) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'pf-v6-c-button pf-m-plain pf-m-small';
        btn.setAttribute('aria-label', label);
        btn.innerHTML = `
            <span class="pf-v6-c-button__icon">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v8h-2V9zm4 0h2v8h-2V9zM7 9h2v8H7V9z"/>
                </svg>
            </span>
        `;
        return btn;
    }

    function renderTextField(group, key, schema, value, path, fieldId) {
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
        input.id = fieldId;
        input.className = 'pf-v6-c-form-control pf-v6-u-flex-grow-1';
        input.addEventListener('input', (e) => updateFieldValue(path, e.target.value));
        group.appendChild(input);
    }

    function renderNumberField(group, key, schema, value, path, fieldId) {
        const input = document.createElement('input');
        input.type = 'number';
        input.value = value !== undefined ? value : '';
        input.placeholder = schema.default !== undefined ? schema.default : '';
        if (schema.minimum !== undefined) input.min = schema.minimum;
        if (schema.maximum !== undefined) input.max = schema.maximum;
        input.dataset.path = path;
        input.id = fieldId;
        input.className = 'pf-v6-c-form-control pf-v6-u-flex-grow-1';
        input.addEventListener('input', (e) => {
            const val = e.target.value === '' ? undefined : Number(e.target.value);
            updateFieldValue(path, val);
        });
        group.appendChild(input);
    }

    function renderBooleanField(group, key, schema, value, path, fieldId) {
        const select = document.createElement('select');
        select.dataset.path = path;
        select.id = fieldId;
        select.className = 'pf-v6-c-form-control pf-v6-u-flex-grow-1';
        select.innerHTML = `
            <option value="">-- Select --</option>
            <option value="true" ${value === true ? 'selected' : ''}>Yes</option>
            <option value="false" ${value === false ? 'selected' : ''}>No</option>
        `;
        select.addEventListener('change', (e) => {
            const val = e.target.value === '' ? undefined : e.target.value === 'true';
            updateFieldValue(path, val);
        });
        group.appendChild(select);
    }

    function renderEnumField(group, key, schema, value, path, fieldId) {
        const select = document.createElement('select');
        select.dataset.path = path;
        select.id = fieldId;
        select.className = 'pf-v6-c-form-control pf-v6-u-flex-grow-1';
        select.innerHTML = `<option value="">-- Select --</option>`;
        schema.enum.forEach(opt => {
            const option = document.createElement('option');
            option.value = opt;
            option.textContent = opt;
            option.selected = value === opt;
            select.appendChild(option);
        });
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
        wrapper.className = 'pf-v6-l-flex pf-m-wrap pf-m-space-items-sm pf-m-align-items-center';

        if (numberOption && (booleanFalseOption || booleanTrueOption) && !enumOption && !objectOption && !stringOption) {
            const select = document.createElement('select');
            select.className = 'pf-v6-c-form-control';
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
            numberInput.className = 'pf-v6-c-form-control';
            if (numberOption.minimum !== undefined) numberInput.min = numberOption.minimum;
            if (numberOption.maximum !== undefined) numberInput.max = numberOption.maximum;
            numberInput.hidden = currentMode !== 'number';
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
                    numberInput.hidden = false;
                    if (numberInput.value === '') {
                        updateFieldValue(path, undefined);
                    } else {
                        const parsed = numberOption.type === 'integer' ? parseInt(numberInput.value, 10) : Number(numberInput.value);
                        updateFieldValue(path, parsed);
                    }
                } else {
                    numberInput.hidden = true;
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
            modeSelect.className = 'pf-v6-c-form-control';
            modeSelect.innerHTML = `
                <option value="structured" ${isObject ? 'selected' : ''}>Structured</option>
                <option value="simple" ${!isObject ? 'selected' : ''}>Simple String</option>
            `;
            wrapper.appendChild(modeSelect);

            const structuredContainer = document.createElement('div');
            structuredContainer.className = 'pf-v6-c-card pf-v6-u-mt-sm pf-v6-u-mb-sm pf-v6-u-w-100';
            structuredContainer.hidden = !isObject;
            const structuredBody = document.createElement('div');
            structuredBody.className = 'pf-v6-c-card__body pf-v6-c-form pf-m-horizontal';
            structuredContainer.appendChild(structuredBody);
            
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
                    propGroup.className = 'pf-v6-c-form__group pf-v6-u-mb-sm';
                    
                    const propLabelWrap = document.createElement('div');
                    propLabelWrap.className = 'pf-v6-c-form__group-label';
                    const propLabel = document.createElement('label');
                    propLabel.className = 'pf-v6-c-form__label';
                    const propLabelText = document.createElement('span');
                    propLabelText.className = 'pf-v6-c-form__label-text';
                    propLabelText.textContent = propSchema.title || capitalizeFirst(propKey);
                    propLabel.appendChild(propLabelText);
                    propLabelWrap.appendChild(propLabel);
                    propGroup.appendChild(propLabelWrap);
                    const propControl = document.createElement('div');
                    propControl.className = 'pf-v6-c-form__group-control';
                    propGroup.appendChild(propControl);
                    
                    const propType = propSchema.type || (Array.isArray(propValue) ? 'array' : typeof propValue === 'boolean' ? 'boolean' : typeof propValue === 'number' ? 'number' : 'string');
                    
                    if (propType === 'boolean') {
                        const select = document.createElement('select');
                        select.dataset.path = propPath;
                        select.className = 'pf-v6-c-form-control';
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
                        propControl.appendChild(select);
                    } else if (propType === 'number' || propType === 'integer') {
                        const propInput = document.createElement('input');
                        propInput.type = 'number';
                        propInput.value = propValue !== undefined ? propValue : '';
                        propInput.placeholder = propSchema.description ? propSchema.description.substring(0, 50) : '';
                        propInput.dataset.path = propPath;
                        propInput.className = 'pf-v6-c-form-control';
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
                        propControl.appendChild(propInput);
                    } else if (propType === 'array') {
                        const arrayContainer = document.createElement('div');
                        arrayContainer.className = 'pf-v6-c-card pf-v6-u-p-sm';
                        const items = Array.isArray(propValue) ? propValue : [];
                        items.forEach((item, idx) => {
                            const itemRow = document.createElement('div');
                            itemRow.className = 'pf-v6-l-flex pf-m-space-items-sm pf-m-align-items-center pf-v6-u-mb-sm';
                            const itemInput = document.createElement('input');
                            itemInput.type = 'text';
                            itemInput.value = item || '';
                            itemInput.className = 'pf-v6-c-form-control pf-v6-u-flex-grow-1';
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
                            const removeBtn = createTrashButton('Remove item');
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
                        addBtn.className = 'pf-v6-c-button pf-m-link pf-m-inline';
                        addBtn.textContent = 'Add item';
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
                        propControl.appendChild(arrayContainer);
                    } else {
                        const propInput = document.createElement('input');
                        propInput.type = 'text';
                        propInput.value = propValue !== undefined ? propValue : '';
                        propInput.placeholder = propSchema.description ? propSchema.description.substring(0, 50) : '';
                        propInput.dataset.path = propPath;
                        propInput.className = 'pf-v6-c-form-control';
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
                        propControl.appendChild(propInput);
                    }
                    structuredBody.appendChild(propGroup);
                });
            }
            wrapper.appendChild(structuredContainer);

            const simpleContainer = document.createElement('div');
            simpleContainer.className = 'pf-v6-u-mt-sm pf-v6-u-w-100';
            simpleContainer.hidden = isObject;
            
            const simpleInput = document.createElement('input');
            simpleInput.type = 'text';
            simpleInput.value = !isObject && value ? value : '';
            simpleInput.placeholder = stringOption.description ? stringOption.description.substring(0, 50) : 'Enter value...';
            simpleInput.dataset.path = path;
            simpleInput.className = 'pf-v6-c-form-control';
            simpleInput.addEventListener('input', (e) => updateFieldValue(path, e.target.value || undefined));
            simpleContainer.appendChild(simpleInput);
            wrapper.appendChild(simpleContainer);

            modeSelect.addEventListener('change', (e) => {
                const isStructured = e.target.value === 'structured';
                structuredContainer.hidden = !isStructured;
                simpleContainer.hidden = isStructured;
                if (isStructured) {
                    updateFieldValue(path, {});
                } else {
                    updateFieldValue(path, '');
                }
            });
        } else if (enumOption && enumOption.enum) {
            const select = document.createElement('select');
            select.dataset.path = path;
            select.className = 'pf-v6-c-form-control';
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
            customInput.hidden = !(value && !enumOption.enum.includes(value));
            customInput.className = 'pf-v6-c-form-control pf-v6-u-mt-sm pf-v6-u-w-100';
            customInput.value = (value && !enumOption.enum.includes(value)) ? value : '';

            select.addEventListener('change', (e) => {
                if (e.target.value === '__custom__') {
                    customInput.hidden = false;
                    customInput.focus();
                } else {
                    customInput.hidden = true;
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

    function renderFileField(group, key, schema, value, path, fieldId) {
        const wrapper = document.createElement('div');
        wrapper.className = 'pf-v6-c-input-group';

        const input = document.createElement('input');
        input.type = 'text';
        input.value = value || '';
        input.placeholder = 'Path to file...';
        input.dataset.path = path;
        input.id = fieldId;
        input.className = 'pf-v6-c-form-control';
        input.addEventListener('input', (e) => updateFieldValue(path, e.target.value || undefined));

        const indicator = document.createElement('span');
        indicator.className = 'pf-v6-c-input-group__text';
        indicator.textContent = 'File Path';

        wrapper.appendChild(input);
        wrapper.appendChild(indicator);
        group.appendChild(wrapper);
    }

    function renderArrayField(group, key, schema, value, path) {
        const wrapper = document.createElement('div');
        wrapper.className = 'pf-v6-l-stack pf-m-gutter';
        wrapper.dataset.path = path;

        const items = Array.isArray(value) ? value : [];
        const itemSchema = schema.items || {};

        const controls = document.createElement('div');
        controls.className = 'pf-v6-c-toolbar array-controls action-cluster';
        controls.innerHTML = `
            <div class="pf-v6-c-toolbar__content">
                <div class="pf-v6-c-toolbar__content-section pf-m-align-items-center pf-m-nowrap pf-v6-u-ml-auto">
                    <div class="pf-v6-c-toolbar__item">
                        <button class="pf-v6-c-button pf-m-secondary array-add-btn" type="button">Add item</button>
                    </div>
                    <div class="pf-v6-c-toolbar__item">
                        <button class="pf-v6-c-button pf-m-danger array-delete-btn" type="button">Delete all</button>
                    </div>
                </div>
            </div>
        `;
        const addBtn = controls.querySelector('.array-add-btn');
        addBtn.addEventListener('click', () => addArrayItem(path, itemSchema));
        const deleteBtn = controls.querySelector('.array-delete-btn');
        deleteBtn.disabled = items.length === 0;
        deleteBtn.addEventListener('click', () => removeAllArrayItems(path));
        wrapper.appendChild(controls);

        items.forEach((item, index) => {
            const itemPath = `${path}[${index}]`;
            if (itemSchema.type === 'object') {
                renderArrayObjectItem(wrapper, itemSchema, item, itemPath, index);
            } else {
                renderArrayPrimitiveItem(wrapper, itemSchema, item, itemPath, index);
            }
        });

        group.appendChild(wrapper);
    }

    function renderArrayPrimitiveItem(wrapper, schema, value, path, index) {
        const item = document.createElement('div');
        item.className = 'pf-v6-l-stack__item pf-v6-l-flex pf-m-space-items-sm pf-m-align-items-center array-item-row';

        const input = document.createElement('input');
        input.type = schema.type === 'number' || schema.type === 'integer' ? 'number' : 'text';
        input.value = value !== undefined ? value : '';
        input.dataset.path = path;
        input.className = 'pf-v6-c-form-control pf-v6-u-flex-grow-1';
        input.addEventListener('input', (e) => {
            const val = schema.type === 'number' || schema.type === 'integer' 
                ? (e.target.value === '' ? undefined : Number(e.target.value))
                : e.target.value;
            updateArrayItemValue(path, val);
        });

        const removeBtn = createTrashButton('Remove item');
        removeBtn.addEventListener('click', () => removeArrayItem(path));

        item.appendChild(input);
        item.appendChild(removeBtn);
        wrapper.appendChild(item);
    }

    function renderArrayObjectItem(wrapper, schema, value, path, index) {
        const item = document.createElement('div');
        item.className = 'pf-v6-l-stack__item pf-v6-c-card';

        const header = document.createElement('div');
        header.className = 'pf-v6-c-card__header pf-v6-u-display-flex pf-v6-u-justify-content-space-between pf-v6-u-align-items-center';
        header.innerHTML = `<div class="pf-v6-c-card__title"><span>Item ${index + 1}</span></div>`;

        const removeBtn = createTrashButton('Remove item');
        removeBtn.addEventListener('click', () => removeArrayItem(path));
        header.appendChild(removeBtn);

        const body = document.createElement('div');
        body.className = 'pf-v6-c-card__body';
        renderObjectFields(body, schema, value, path);

        item.appendChild(header);
        item.appendChild(body);
        wrapper.appendChild(item);
    }

    function renderNestedObjectField(group, key, schema, value, path) {
        const wrapper = document.createElement('div');
        wrapper.className = 'pf-v6-c-card';

        const header = document.createElement('div');
        header.className = 'pf-v6-c-card__header';
        header.innerHTML = `<div class="pf-v6-c-card__title"><span>${schema.title || capitalizeFirst(key)}</span></div>`;

        const body = document.createElement('div');
        body.className = 'pf-v6-c-card__body';
        renderObjectFields(body, schema, value || {}, path);

        wrapper.appendChild(header);
        wrapper.appendChild(body);
        group.appendChild(wrapper);
    }

    function renderHostsSection(container, schema, data) {
        const toolbar = document.createElement('div');
        toolbar.className = 'pf-v6-c-toolbar pf-v6-u-mb-md';
        toolbar.innerHTML = `
            <div class="pf-v6-c-toolbar__content">
                <div class="pf-v6-c-toolbar__content-section pf-m-align-items-center">
                    <div class="pf-v6-c-toolbar__item">
                        <h3 class="pf-v6-c-title pf-m-md">Hosts (${Object.keys(data || {}).length})</h3>
                    </div>
                </div>
                <div class="pf-v6-c-toolbar__content-section pf-m-align-items-center pf-m-nowrap">
                    <div class="pf-v6-c-toolbar__item">
                        <button class="pf-v6-c-button pf-m-primary add-host-btn">+ Add Host</button>
                    </div>
                </div>
            </div>
        `;
        toolbar.querySelector('.add-host-btn').addEventListener('click', addHost);
        container.appendChild(toolbar);

        const hostsContainer = document.createElement('div');
        hostsContainer.id = 'hosts-container';
        hostsContainer.className = 'pf-v6-l-stack pf-m-gutter';

        Object.entries(data || {}).forEach(([hostname, hostData]) => {
            renderHostCard(hostsContainer, hostname, hostData, schema);
        });

        container.appendChild(hostsContainer);
    }

    function renderHostCard(container, hostname, data, schema) {
        const card = document.createElement('div');
        card.className = 'pf-v6-l-stack__item pf-v6-c-card host-card';
        card.dataset.hostname = hostname;

        const role = data.role || 'worker';
        const roleClass = role === 'control' ? 'pf-m-blue' : 'pf-m-green';

        card.innerHTML = `
            <div class="pf-v6-c-card__header pf-v6-u-display-flex pf-v6-u-justify-content-space-between pf-v6-u-align-items-center">
                <div class="pf-v6-c-card__title">
                    <span>${hostname}</span>
                    <span class="pf-v6-c-label pf-m-compact ${roleClass} pf-v6-u-ml-sm"><span class="pf-v6-c-label__content">${role}</span></span>
                </div>
                <div class="pf-v6-l-flex pf-m-space-items-sm pf-m-align-items-center action-cluster">
                    <button class="pf-v6-c-button pf-m-secondary pf-m-small duplicate-btn" title="Duplicate host">Duplicate</button>
                    <button class="pf-v6-c-button pf-m-secondary pf-m-small remove-btn" title="Remove host">Remove</button>
                    <button class="pf-v6-c-button pf-m-link pf-m-inline pf-m-small toggle-btn">Expand</button>
                </div>
            </div>
            <div class="pf-v6-c-card__body host-card-body"></div>
        `;

        const header = card.querySelector('.pf-v6-c-card__header');
        const body = card.querySelector('.host-card-body');
        body.hidden = true;
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
        container.classList.add('pf-v6-c-form', 'pf-m-horizontal');
        const hostname = getHostnameFromPath(path);
        const hostnameGroup = document.createElement('div');
        hostnameGroup.className = 'pf-v6-c-form__group';

        const labelWrap = document.createElement('div');
        labelWrap.className = 'pf-v6-c-form__group-label';
        const label = document.createElement('label');
        label.className = 'pf-v6-c-form__label';
        label.htmlFor = `host-${hostname}`;
        const labelText = document.createElement('span');
        labelText.className = 'pf-v6-c-form__label-text';
        labelText.textContent = 'Hostname';
        label.appendChild(labelText);
        labelWrap.appendChild(label);

        const controlWrap = document.createElement('div');
        controlWrap.className = 'pf-v6-c-form__group-control';
        const input = document.createElement('input');
        input.type = 'text';
        input.value = hostname;
        input.id = `host-${hostname}`;
        input.dataset.hostnameInput = 'true';
        input.className = 'pf-v6-c-form-control';
        input.addEventListener('change', (e) => {
            renameHost(hostname, e.target.value);
        });
        controlWrap.appendChild(input);

        hostnameGroup.appendChild(labelWrap);
        hostnameGroup.appendChild(controlWrap);
        container.appendChild(hostnameGroup);

        renderObjectFields(container, schema, data, path);
    }

    function toggleHostCard(card) {
        const body = card.querySelector('.host-card-body');
        const btn = card.querySelector('.toggle-btn');
        if (!body || !btn) return;
        body.hidden = !body.hidden;
        btn.textContent = body.hidden ? 'Expand' : 'Collapse';
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
        const group = document.querySelector(`.pf-v6-c-form__group[data-path="${path}"]`);
        if (group) {
            const revertBtn = group.querySelector('.revert-btn');
            if (revertBtn) {
                revertBtn.disabled = !hasChanged(path);
            }
        }
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

    function removeAllArrayItems(path) {
        const array = getNestedValue(state.currentObject, path);
        if (Array.isArray(array)) {
            array.length = 0;
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
            resultsContainer.innerHTML = `
                <div class="pf-v6-c-alert pf-m-inline pf-m-info" aria-live="polite">
                    <div class="pf-v6-c-alert__title">No data to validate</div>
                </div>
            `;
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
                resultsContainer.innerHTML = `
                    <div class="pf-v6-c-alert pf-m-inline pf-m-success" aria-live="polite">
                        <div class="pf-v6-c-alert__title">Validation passed</div>
                    </div>
                `;
                state.validationErrors = 0;
            } else {
                resultsContainer.innerHTML = validate.errors.map(error => `
                    <div class="pf-v6-c-alert pf-m-inline pf-m-danger pf-v6-u-mb-sm" aria-live="polite">
                        <div class="pf-v6-c-alert__title">${error.instancePath || '/'}</div>
                        <div class="pf-v6-c-alert__description">${error.message}</div>
                    </div>
                `).join('');
                state.validationErrors = validate.errors.length;
            }
            updateAboutErrorBadge();
            updateHeaderStatus();
        } catch (error) {
            resultsContainer.innerHTML = `
                <div class="pf-v6-c-alert pf-m-inline pf-m-danger" aria-live="polite">
                    <div class="pf-v6-c-alert__title">Validation error</div>
                    <div class="pf-v6-c-alert__description">${error.message}</div>
                </div>
            `;
            state.validationErrors = 1;
            updateAboutErrorBadge();
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
            container.innerHTML = `
                <div class="pf-v6-c-alert pf-m-inline pf-m-info" aria-live="polite">
                    <div class="pf-v6-c-alert__title">No changes</div>
                </div>
            `;
            updateHeaderStatus();
            updateNavChangeBadges();
            return;
        }

        container.innerHTML = state.changes.map(change => `
            <div class="pf-v6-l-flex pf-m-space-items-sm pf-m-align-items-center pf-v6-u-mb-sm">
                <span class="pf-v6-u-flex-grow-1">${change.path}</span>
                <button class="pf-v6-c-button pf-m-link pf-m-inline revert-change" data-path="${change.path}">Revert</button>
            </div>
        `).join('');

        container.querySelectorAll('.revert-change').forEach(btn => {
            btn.addEventListener('click', () => revertField(btn.dataset.path));
        });
        
        updateHeaderStatus();
        updateNavChangeBadges();
    }

    function updateHeaderStatus() {
        const filenameEl = document.getElementById('header-filename');
        const contentFilenameEl = document.getElementById('content-filename');
        const changesCountEl = document.getElementById('changes-count');
        const errorsCountEl = document.getElementById('errors-count');
        const changesEl = document.getElementById('header-changes');
        const errorsEl = document.getElementById('header-errors');
        
        if (filenameEl) filenameEl.textContent = '';
        if (contentFilenameEl) contentFilenameEl.textContent = state.currentFilename;
        if (changesCountEl) changesCountEl.textContent = state.changes.length;
        if (errorsCountEl) errorsCountEl.textContent = state.validationErrors;
        updateSaveButton();
        updateAboutErrorBadge();
        
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
            container.textContent = 'No changes from baseline';
            return;
        }

        try {
            const diff = Diff.createTwoFilesPatch('baseline.yaml', 'current.yaml', state.baselineYamlText, state.currentYamlText);
            container.textContent = diff;
        } catch (error) {
            container.textContent = 'Failed to generate diff';
        }
    }

    function formatDiff(diff) {
        return diff;
    }

    function showParseError(error) {
        const container = document.getElementById('error-results');
        container.innerHTML = `
            <div class="pf-v6-c-alert pf-m-inline pf-m-danger" aria-live="polite">
                <div class="pf-v6-c-alert__title">YAML parse error</div>
                <div class="pf-v6-c-alert__description">${escapeHtml(error.message)}</div>
            </div>
        `;
        state.validationErrors = 1;
        updateAboutErrorBadge();
        showToast(`YAML parse error: ${error.message}`, 'error');
    }

    function clearParseError() {
        const container = document.getElementById('error-results');
        container.innerHTML = `
            <div class="pf-v6-c-alert pf-m-inline pf-m-info" aria-live="polite">
                <div class="pf-v6-c-alert__title">No errors</div>
            </div>
        `;
        state.validationErrors = 0;
        updateAboutErrorBadge();
    }

    function showError(message) {
        const container = document.getElementById('error-results');
        container.innerHTML = `
            <div class="pf-v6-c-alert pf-m-inline pf-m-danger" aria-live="polite">
                <div class="pf-v6-c-alert__title">Error</div>
                <div class="pf-v6-c-alert__description">${escapeHtml(message)}</div>
            </div>
        `;
        state.validationErrors = 1;
        updateAboutErrorBadge();
        showToast(message, 'error');
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

    function handleHelpFocus(e) {
        if (state.pinnedHelp) return;
        showHelpBubble(e.currentTarget);
    }

    function handleHelpBlur() {
        if (!state.pinnedHelp) {
            hideHelpBubble();
        }
    }

    function handleHelpClick(e) {
        e.stopPropagation();
        e.preventDefault();
        const target = e.currentTarget;
        if (state.pinnedHelp && state.helpTarget === target) {
            forceHideHelpBubble();
            return;
        }
        state.pinnedHelp = true;
        showHelpBubble(target);
        updatePinButtonIcon();
    }

    function handleHelpReposition() {
        const bubble = document.getElementById('help-bubble');
        if (!bubble || bubble.style.display !== 'block' || !state.helpTarget) return;
        positionHelpBubble(state.helpTarget);
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
        state.helpTarget = target;

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

        positionHelpBubble(target);
        bubble.style.visibility = 'visible';
    }

    function positionHelpBubble(target) {
        const bubble = document.getElementById('help-bubble');
        if (!bubble) return;
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
    }

    function hideHelpBubble() {
        if (state.pinnedHelp) return;
        document.getElementById('help-bubble').style.display = 'none';
        state.helpTarget = null;
    }

    function forceHideHelpBubble() {
        state.pinnedHelp = false;
        document.getElementById('help-bubble').style.display = 'none';
        state.helpTarget = null;
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
        setCurrentFilename('untitled');
        markUnsaved();
        restoreSectionForFile();
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
            setCurrentFilename(file.name);
            markUnsaved();
            restoreSectionForFile();
        };
        reader.readAsText(file);
        e.target.value = '';
    }

    function toggleNavGroup(menu) {
        const list = document.querySelector(`[data-menu-list="${menu}"]`);
        const button = document.querySelector(`.nav-group-toggle[data-menu="${menu}"]`);
        const item = button ? button.closest('.pf-v6-c-nav__item') : null;
        if (!list || !button || !item) return;
        const isExpanded = item.classList.contains('pf-m-expanded');
        item.classList.toggle('pf-m-expanded', !isExpanded);
        button.setAttribute('aria-expanded', !isExpanded ? 'true' : 'false');
        const subnav = button.nextElementSibling;
        if (subnav && subnav.classList.contains('pf-v6-c-nav__subnav')) {
            if (!isExpanded) {
                subnav.removeAttribute('hidden');
            } else {
                subnav.setAttribute('hidden', '');
            }
        }
    }

    function updateNavGroupCurrent(section) {
        const clusterButton = document.querySelector('.nav-group-toggle[data-menu="clusterfile"]');
        const templatesButton = document.querySelector('.nav-group-toggle[data-menu="templates"]');
        const aboutButton = document.querySelector('.nav-group-toggle[data-menu="about"]');
        const clusterList = document.querySelector('[data-menu-list="clusterfile"]');
        const templatesList = document.querySelector('[data-menu-list="templates"]');
        const aboutList = document.querySelector('[data-menu-list="about"]');
        const clusterItem = clusterButton ? clusterButton.closest('.pf-v6-c-nav__item') : null;
        const templatesItem = templatesButton ? templatesButton.closest('.pf-v6-c-nav__item') : null;
        const aboutItem = aboutButton ? aboutButton.closest('.pf-v6-c-nav__item') : null;

        const clusterActive = FILE_SECTIONS.includes(section) || state.editorView === EDITOR_VIEWS.CLUSTERFILE;
        const templatesActive = section === 'templates' || state.editorView === EDITOR_VIEWS.TEMPLATES;

        if (clusterButton) clusterButton.classList.toggle('pf-m-current', clusterActive);
        if (templatesButton) templatesButton.classList.toggle('pf-m-current', templatesActive);
        if (aboutButton) aboutButton.classList.toggle('pf-m-current', section === 'about' || section === 'changelog');

        if (clusterActive && clusterList && clusterButton) {
            if (clusterItem) clusterItem.classList.add('pf-m-expanded');
            clusterButton.setAttribute('aria-expanded', 'true');
            const subnav = clusterButton.nextElementSibling;
            if (subnav && subnav.classList.contains('pf-v6-c-nav__subnav')) {
                subnav.removeAttribute('hidden');
            }
        }

        if (templatesActive && templatesList && templatesButton) {
            if (templatesItem) templatesItem.classList.add('pf-m-expanded');
            templatesButton.setAttribute('aria-expanded', 'true');
            const subnav = templatesButton.nextElementSibling;
            if (subnav && subnav.classList.contains('pf-v6-c-nav__subnav')) {
                subnav.removeAttribute('hidden');
            }
        }

        if ((section === 'about' || section === 'changelog') && aboutList && aboutButton) {
            if (aboutItem) aboutItem.classList.add('pf-m-expanded');
            aboutButton.setAttribute('aria-expanded', 'true');
            const subnav = aboutButton.nextElementSibling;
            if (subnav && subnav.classList.contains('pf-v6-c-nav__subnav')) {
                subnav.removeAttribute('hidden');
            }
        }
    }

    function updateSectionDescription(section) {
        const descEl = document.getElementById('section-description');
        if (!descEl) return;
        let description = '';
        if (state.schema && state.schema.properties && state.schema.properties[section]) {
            description = state.schema.properties[section].description || '';
        }
        descEl.textContent = description;
        descEl.style.display = description ? 'block' : 'none';
    }

    function handleEditorToggle(view) {
        setEditorMode(view);
    }

    function setEditorMode(view, options = {}) {
        const { fromSection = false } = options;
        if (!fromSection) {
            if (view === EDITOR_VIEWS.TEMPLATES) {
                if (state.currentSection !== 'templates') {
                    switchSection('templates', { fromEditor: true });
                }
            } else if (state.currentSection === 'templates') {
                restoreSectionForFile();
            }
        }
        setEditorView(view);
    }

    function setEditorView(view) {
        state.editorView = view;
        const yamlEditorContainer = document.querySelector('.yaml-editor-container');
        const templateOutputPane = document.getElementById('template-output-pane');
        const tabsContainer = document.querySelector('.tabs-container');
        if (!yamlEditorContainer || !templateOutputPane || !tabsContainer) return;
        if (view === EDITOR_VIEWS.TEMPLATES) {
            setVisibility(yamlEditorContainer, false);
            setVisibility(templateOutputPane, true);
            setVisibility(tabsContainer, false);
            refreshTemplateOutputEditor();
        } else {
            setVisibility(yamlEditorContainer, true);
            setVisibility(templateOutputPane, false);
            setVisibility(tabsContainer, true);
            if (!state.currentTab) {
                state.currentTab = 'validation';
            }
            switchTab(state.currentTab);
        }
        document.querySelectorAll('.editor-toggle-btn').forEach(btn => {
            const isActive = btn.dataset.editorView === view;
            const tabItem = btn.closest('.pf-v6-c-tabs__item');
            if (tabItem) {
                tabItem.classList.toggle('pf-m-current', isActive);
            }
            btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
        });
        updateNavGroupCurrent(state.currentSection);
        localStorage.setItem(STORAGE_KEYS.LAST_EDITOR_VIEW, view);
    }

    function setVisibility(element, shouldShow) {
        element.hidden = !shouldShow;
        element.classList.toggle('is-hidden', !shouldShow);
        if (shouldShow) {
            element.style.display = '';
        } else {
            element.style.display = 'none';
        }
    }

    function setTheme(theme) {
        const isDark = theme === 'dark';
        document.documentElement.classList.toggle('pf-v6-theme-dark', isDark);
        document.body.classList.toggle('pf-v6-theme-dark', isDark);
        const header = document.querySelector('.pf-v6-c-page__header');
        const sidebar = document.querySelector('.pf-v6-c-page__sidebar');
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            themeToggle.checked = isDark;
        }
        localStorage.setItem(STORAGE_KEYS.THEME, isDark ? 'dark' : 'light');
    }

    function toggleParamsPanel() {
        const panel = document.getElementById('params-panel');
        const toggle = document.getElementById('toggle-params');
        if (!panel || !toggle) return;
        const isOpen = panel.style.display === 'block';
        panel.style.display = isOpen ? 'none' : 'block';
        toggle.textContent = isOpen ? 'Show JSONPath Overrides' : 'Hide JSONPath Overrides';
    }

    function rememberSectionForFile(section) {
        const map = getSectionMap();
        map[state.currentFilename || 'untitled'] = section;
        localStorage.setItem(STORAGE_KEYS.LAST_SECTION_BY_FILE, JSON.stringify(map));
    }

    function restoreSectionForFile() {
        const map = getSectionMap();
        const key = state.currentFilename || 'untitled';
        const section = map[key] || FILE_SECTIONS[0];
        if (section !== state.currentSection) {
            switchSection(section);
        }
    }

    function getSectionMap() {
        try {
            return JSON.parse(localStorage.getItem(STORAGE_KEYS.LAST_SECTION_BY_FILE)) || {};
        } catch {
            return {};
        }
    }

    function updateNavChangeBadges() {
        FILE_SECTIONS.forEach(section => {
            const badge = document.querySelector(`[data-badge="${section}"]`);
            if (!badge) return;
            const count = state.changes.filter(change =>
                change.path === section ||
                change.path.startsWith(`${section}.`) ||
                change.path.startsWith(`${section}[`)
            ).length;
            if (count > 0) {
                badge.textContent = count;
                badge.style.display = 'inline-block';
            } else {
                badge.textContent = '';
                badge.style.display = 'none';
            }
        });
    }

    function updateAboutErrorBadge() {
        const badge = document.querySelector('[data-badge="about-errors"]');
        if (!badge) return;
        if (state.validationErrors > 0) {
            badge.textContent = state.validationErrors;
            badge.style.display = 'inline-block';
        } else {
            badge.textContent = '';
            badge.style.display = 'none';
        }
    }

    function setCurrentFilename(name) {
        state.currentFilename = name || 'untitled';
        localStorage.setItem(STORAGE_KEYS.LAST_FILENAME, state.currentFilename);
        updateHeaderStatus();
    }

    function markUnsaved() {
        updateSaveButton();
    }

    function updateSaveButton() {
        const saveBtn = document.getElementById('btn-save');
        if (!saveBtn) return;
        let normalized = '';
        try {
            normalized = buildNormalizedYaml();
        } catch {
            normalized = state.currentYamlText;
        }
        const isSaved = state.lastSavedYaml && state.lastSavedYaml === normalized && state.changes.length === 0;
        saveBtn.classList.toggle('pf-m-primary', !isSaved);
        saveBtn.classList.toggle('pf-m-secondary', isSaved);
        saveBtn.textContent = isSaved ? 'Saved' : 'Save';
    }

    function saveToLocalStorage() {
        const yamlToSave = redactSecrets(buildNormalizedYaml());
        localStorage.setItem(STORAGE_KEYS.LAST_YAML, yamlToSave);
        state.lastSavedYaml = yamlToSave;
        updateSaveButton();
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
            showToast('Copied to clipboard');
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

    function initDevReload() {
        let lastToken = null;
        let stopped = false;

        async function poll() {
            if (stopped) return;
            try {
                const response = await fetch('/api/dev/reload-token', { cache: 'no-store' });
                if (response.status === 404) {
                    stopped = true;
                    return;
                }
                if (response.ok) {
                    const data = await response.json();
                    if (lastToken !== null && data.token !== lastToken) {
                        window.location.reload();
                        return;
                    }
                    lastToken = data.token;
                }
            } catch (error) {
                // Ignore transient errors; keep polling.
            }
            setTimeout(poll, 1000);
        }

        poll();
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
            tabSize: 2,
            foldGutter: true,
            gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter']
        });
        setTemplateOutputView('rendered');
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
                const removeBtn = e.target.closest('.remove-param-btn');
                if (removeBtn) {
                    removeParamRow(removeBtn);
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

        document.querySelectorAll('.output-view-btn').forEach(btn => {
            btn.addEventListener('click', () => setTemplateOutputView(btn.dataset.outputView));
        });

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
        if (selectedOption && selectedOption.value !== templateState.lastTemplateName) {
            templateState.lastTemplateSource = '';
        }
    }

    function addParamRow() {
        const container = document.getElementById('params-container');
        const row = document.createElement('div');
        row.className = 'param-row pf-v6-l-flex pf-m-space-items-sm pf-m-align-items-center pf-v6-u-mb-sm';
        row.innerHTML = `
            <input type="text" class="pf-v6-c-form-control param-path" placeholder="$.hosts[*].bmc.username" title="JSONPath expression">
            <input type="text" class="pf-v6-c-form-control param-value" placeholder="new-value" title="Value to set">
            <button class="remove-param-btn pf-v6-c-button pf-m-plain pf-m-small" type="button" title="Remove" aria-label="Remove override">
                <span class="pf-v6-c-button__icon">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                        <path d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v8h-2V9zm4 0h2v8h-2V9zM7 9h2v8H7V9z"/>
                    </svg>
                </span>
            </button>
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
        if (templateState.rendering) return;
        const templateSelect = document.getElementById('template-select');
        let templateName = templateSelect ? templateSelect.value : '';
        if (!templateName) {
            if (templateState.templates.length > 0 && templateSelect) {
                templateName = templateState.templates[0].name;
                templateSelect.value = templateName;
                handleTemplateSelect({ target: templateSelect });
            } else {
                showToast('Please select a template', 'error');
                return;
            }
        }

        const yamlText = state.currentYamlText;
        if (!yamlText || yamlText.trim() === '') {
            showToast('Please load or create a clusterfile first', 'error');
            return;
        }

        const params = getParams();

        try {
            templateState.rendering = true;
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
                templateState.lastTemplateName = templateName;
                templateState.lastRenderedInput = buildNormalizedYaml({ preserveCurrentText: true });
                templateState.outputEditor.setValue(result.output);
                setTemplateOutputView('rendered');
                refreshTemplateOutputEditor();
                
                const warningsEl = document.getElementById('template-warnings');
                if (result.warnings && result.warnings.length > 0) {
                    warningsEl.innerHTML = `
                        <div class="pf-v6-c-alert pf-m-inline pf-m-warning" aria-live="polite">
                            <div class="pf-v6-c-alert__title">Warnings</div>
                            <div class="pf-v6-c-alert__description">${result.warnings.join('<br>')}</div>
                        </div>
                    `;
                } else {
                    warningsEl.innerHTML = `
                        <div class="pf-v6-c-helper-text">
                            <div class="pf-v6-c-helper-text__item">Rendered output</div>
                        </div>
                    `;
                }
                
                clearTemplateError();
            } else {
                showTemplateError(result.error || 'Rendering failed');
            }
        } catch (error) {
            console.error('Failed to render template:', error);
            showTemplateError('Failed to render template: ' + error.message);
        } finally {
            templateState.rendering = false;
        }
    }

    async function previewTemplateSource() {
        const templateName = document.getElementById('template-select').value;
        if (!templateName) {
            showToast('Please select a template', 'error');
            return;
        }

        try {
            const response = await fetch(getApiBase() + `/api/templates/${templateName}`);
            const result = await response.json();

            if (response.ok) {
                templateState.lastTemplateSource = result.content;
                templateState.lastTemplateName = templateName;
                templateState.outputEditor.setValue(result.content);
                setTemplateOutputView('source');
                refreshTemplateOutputEditor();
                const warningsEl = document.getElementById('template-warnings');
                if (warningsEl) {
                    warningsEl.innerHTML = `
                        <div class="pf-v6-c-alert pf-m-inline pf-m-info" aria-live="polite">
                            <div class="pf-v6-c-alert__title">Template source</div>
                            <div class="pf-v6-c-alert__description">Showing template source (not rendered output).</div>
                        </div>
                    `;
                }
            } else {
                showTemplateError(result.detail || 'Failed to load template');
            }
        } catch (error) {
            console.error('Failed to preview template:', error);
            showTemplateError('Failed to preview template: ' + error.message);
        }
    }

    function setTemplateOutputView(view) {
        templateState.outputView = view;
        document.querySelectorAll('.output-view-btn').forEach(btn => {
            btn.classList.toggle('pf-m-primary', btn.dataset.outputView === view);
            btn.classList.toggle('pf-m-secondary', btn.dataset.outputView !== view);
        });
        document.querySelectorAll('[data-template-view]').forEach(link => {
            link.classList.toggle('pf-m-current', link.dataset.templateView === view);
        });
        if (!templateState.outputEditor) return;
        const warningsEl = document.getElementById('template-warnings');
        if (view === 'rendered') {
            if (warningsEl) {
                warningsEl.innerHTML = `
                    <div class="pf-v6-c-helper-text">
                        <div class="pf-v6-c-helper-text__item">Rendered output</div>
                    </div>
                `;
            }
            const currentInput = buildNormalizedYaml({ preserveCurrentText: true });
            const selectedTemplate = document.getElementById('template-select')?.value || templateState.lastTemplateName;
            const needsRender = !templateState.lastRenderedOutput ||
                templateState.lastRenderedInput !== currentInput ||
                (selectedTemplate && selectedTemplate !== templateState.lastTemplateName);
            if (needsRender) {
                renderTemplate();
            } else {
                templateState.outputEditor.setValue(templateState.lastRenderedOutput || '');
            }
        } else if (view === 'source') {
            if (templateState.lastTemplateSource) {
                templateState.outputEditor.setValue(templateState.lastTemplateSource);
                if (warningsEl) {
                    warningsEl.innerHTML = `
                        <div class="pf-v6-c-alert pf-m-inline pf-m-info" aria-live="polite">
                            <div class="pf-v6-c-alert__title">Template source</div>
                            <div class="pf-v6-c-alert__description">Showing template source (not rendered output).</div>
                        </div>
                    `;
                }
            } else {
                previewTemplateSource();
            }
        } else if (view === 'clusterfile') {
            templateState.outputEditor.setValue(buildNormalizedYaml({ preserveCurrentText: true }));
            if (warningsEl) {
                warningsEl.innerHTML = `
                    <div class="pf-v6-c-alert pf-m-inline pf-m-info" aria-live="polite">
                        <div class="pf-v6-c-alert__title">Clusterfile input</div>
                        <div class="pf-v6-c-alert__description">Showing current clusterfile input.</div>
                    </div>
                `;
            }
        }
        refreshTemplateOutputEditor();
    }

    function refreshTemplateOutputEditor() {
        if (!templateState.outputEditor) return;
        requestAnimationFrame(() => templateState.outputEditor.refresh());
    }

    function showTemplateError(message) {
        let errorEl = document.querySelector('.template-error');
        if (!errorEl) {
            errorEl = document.createElement('div');
            errorEl.className = 'template-error pf-v6-c-alert pf-m-inline pf-m-danger pf-v6-u-mb-md';
            errorEl.innerHTML = `
                <div class="pf-v6-c-alert__title">Template error</div>
                <div class="pf-v6-c-alert__description"></div>
            `;
            const form = document.querySelector('.template-form');
            form.parentNode.insertBefore(errorEl, form);
        }
        const description = errorEl.querySelector('.pf-v6-c-alert__description');
        if (description) {
            description.textContent = message;
        }
        errorEl.style.display = 'block';
    }

    function clearTemplateError() {
        const errorEl = document.querySelector('.template-error');
        if (errorEl) {
            errorEl.style.display = 'none';
        }
    }

    function copyTemplateOutput() {
        const output = templateState.outputEditor ? templateState.outputEditor.getValue() : '';
        if (output) {
            navigator.clipboard.writeText(output).then(() => {
                showToast('Output copied');
            });
        }
    }

    function downloadTemplateOutput() {
        const output = templateState.outputEditor ? templateState.outputEditor.getValue() : '';
        if (!output) return;

        const templateName = document.getElementById('template-select').value;
        let filename = templateName.replace('.tpl', '').replace('.tmpl', '');
        if (templateState.outputView === 'clusterfile') {
            filename = 'clusterfile';
        } else if (templateState.outputView === 'source') {
            filename = `${filename}.tpl`;
        }
        if (templateState.outputView !== 'source' &&
            !filename.endsWith('.yaml') && !filename.endsWith('.yml') && !filename.endsWith('.sh')) {
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
