/**
 * Clusterfile Editor v2.0 - CodeMirror Editor Module
 *
 * Provides YAML editor with syntax highlighting, folding, and sync.
 */
(function() {
'use strict';

let yamlEditor = null;
let outputEditor = null;
let templateEditor = null;
let renderedEditor = null;
let syncTimeout = null;
const SYNC_DELAY = 300;

/**
 * Initialize the YAML editor
 */
function initYamlEditor(container, initialValue = '') {
  if (!window.CodeMirror) {
    console.error('CodeMirror not loaded');
    return null;
  }

  yamlEditor = window.CodeMirror(container, {
    value: initialValue,
    mode: 'yaml',
    theme: 'default',
    lineNumbers: true,
    lineWrapping: true,
    foldGutter: true,
    gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
    indentUnit: 2,
    tabSize: 2,
    indentWithTabs: false,
    extraKeys: {
      'Tab': (cm) => {
        if (cm.somethingSelected()) {
          cm.indentSelection('add');
        } else {
          cm.replaceSelection('  ', 'end');
        }
      },
      'Shift-Tab': (cm) => {
        cm.indentSelection('subtract');
      },
      'Ctrl-Q': (cm) => {
        cm.foldCode(cm.getCursor());
      }
    }
  });

  // Store reference in state
  if (window.EditorState) {
    window.EditorState.state.yamlEditor = yamlEditor;
  }

  return yamlEditor;
}

/**
 * Initialize the output editor (read-only) - legacy, kept for compatibility
 */
function initOutputEditor(container, initialValue = '') {
  if (!window.CodeMirror) {
    console.error('CodeMirror not loaded');
    return null;
  }

  outputEditor = window.CodeMirror(container, {
    value: initialValue,
    mode: 'yaml',
    theme: 'default',
    lineNumbers: true,
    lineWrapping: true,
    foldGutter: true,
    gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
    readOnly: true
  });

  // Store reference in state
  if (window.EditorState) {
    window.EditorState.state.outputEditor = outputEditor;
  }

  return outputEditor;
}

/**
 * Initialize the template source editor (read-only)
 */
function initTemplateEditor(container, initialValue = '') {
  if (!window.CodeMirror) {
    console.error('CodeMirror not loaded');
    return null;
  }

  templateEditor = window.CodeMirror(container, {
    value: initialValue,
    mode: 'jinja2',  // Use jinja2 mode if available, fallback to yaml
    theme: 'default',
    lineNumbers: true,
    lineWrapping: true,
    foldGutter: true,
    gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
    readOnly: true
  });

  // Fallback to yaml mode if jinja2 not available
  if (!window.CodeMirror.modes.jinja2) {
    templateEditor.setOption('mode', 'yaml');
  }

  return templateEditor;
}

/**
 * Initialize the rendered output editor (read-only)
 */
function initRenderedEditor(container, initialValue = '') {
  if (!window.CodeMirror) {
    console.error('CodeMirror not loaded');
    return null;
  }

  renderedEditor = window.CodeMirror(container, {
    value: initialValue,
    mode: 'yaml',
    theme: 'default',
    lineNumbers: true,
    lineWrapping: true,
    foldGutter: true,
    gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
    readOnly: true
  });

  return renderedEditor;
}

/**
 * Set up editor change handler with debounce
 */
function setupEditorSync(onSync) {
  if (!yamlEditor) return;

  yamlEditor.on('change', () => {
    clearTimeout(syncTimeout);
    syncTimeout = setTimeout(() => {
      const value = yamlEditor.getValue();
      if (onSync) {
        onSync(value);
      }
    }, SYNC_DELAY);
  });
}

/**
 * Update editor content (without triggering change event loop)
 */
function setEditorValue(value, preserveCursor = true) {
  if (!yamlEditor) return;

  const cursor = preserveCursor ? yamlEditor.getCursor() : null;
  const scrollInfo = preserveCursor ? yamlEditor.getScrollInfo() : null;

  // Check if content actually changed
  if (yamlEditor.getValue() === value) {
    return;
  }

  yamlEditor.setValue(value);

  if (cursor && preserveCursor) {
    // Try to restore cursor position
    const lineCount = yamlEditor.lineCount();
    const line = Math.min(cursor.line, lineCount - 1);
    const lineLength = yamlEditor.getLine(line)?.length || 0;
    const ch = Math.min(cursor.ch, lineLength);
    yamlEditor.setCursor({ line, ch });
  }

  if (scrollInfo && preserveCursor) {
    yamlEditor.scrollTo(scrollInfo.left, scrollInfo.top);
  }
}

/**
 * Get editor content
 */
function getEditorValue() {
  return yamlEditor ? yamlEditor.getValue() : '';
}

/**
 * Set output editor content
 */
function setOutputValue(value) {
  if (outputEditor) {
    outputEditor.setValue(value);
  }
}

/**
 * Get output editor content
 */
function getOutputValue() {
  return outputEditor ? outputEditor.getValue() : '';
}

/**
 * Set template editor content
 */
function setTemplateValue(value) {
  if (templateEditor) {
    templateEditor.setValue(value);
  }
}

/**
 * Get template editor content
 */
function getTemplateValue() {
  return templateEditor ? templateEditor.getValue() : '';
}

/**
 * Set rendered editor content
 */
function setRenderedValue(value) {
  if (renderedEditor) {
    clearRenderedHighlights();
    renderedEditor.setValue(value);
  }
}

/**
 * Get rendered editor content
 */
function getRenderedValue() {
  return renderedEditor ? renderedEditor.getValue() : '';
}

/**
 * Set rendered editor content with diff highlighting
 * Compares against baseline and highlights changed lines
 */
function setRenderedValueWithHighlights(value, baselineValue) {
  if (!renderedEditor) return;

  clearRenderedHighlights();
  renderedEditor.setValue(value);

  if (!baselineValue || value === baselineValue) return;

  // Compare line by line and highlight differences
  const valueLines = value.split('\n');
  const baselineLines = baselineValue.split('\n');

  // Use a simple diff algorithm to find changed lines
  const changes = findChangedLines(baselineLines, valueLines);

  // Apply highlights to changed lines
  changes.forEach(lineNum => {
    if (lineNum < renderedEditor.lineCount()) {
      renderedEditor.addLineClass(lineNum, 'background', 'cm-param-changed');
      renderedEditor.addLineClass(lineNum, 'gutter', 'cm-param-changed-gutter');
    }
  });

  // Scroll to first change if any
  if (changes.length > 0) {
    renderedEditor.scrollIntoView({ line: changes[0], ch: 0 }, 100);
  }
}

/**
 * Find lines that changed between baseline and current
 */
function findChangedLines(baselineLines, currentLines) {
  const changes = [];
  const maxLen = Math.max(baselineLines.length, currentLines.length);

  for (let i = 0; i < maxLen; i++) {
    const baseLine = baselineLines[i] || '';
    const currLine = currentLines[i] || '';

    if (baseLine !== currLine) {
      changes.push(i);
    }
  }

  return changes;
}

/**
 * Clear all highlights from rendered editor
 */
function clearRenderedHighlights() {
  if (!renderedEditor) return;

  const lineCount = renderedEditor.lineCount();
  for (let i = 0; i < lineCount; i++) {
    renderedEditor.removeLineClass(i, 'background', 'cm-param-changed');
    renderedEditor.removeLineClass(i, 'gutter', 'cm-param-changed-gutter');
  }
}

/**
 * Highlight a line in the editor
 */
function highlightLine(lineNumber, className = 'cm-error-line') {
  if (!yamlEditor) return null;

  const lineHandle = yamlEditor.addLineClass(lineNumber, 'background', className);
  return lineHandle;
}

/**
 * Clear line highlights
 */
function clearLineHighlights(className = 'cm-error-line') {
  if (!yamlEditor) return;

  const lineCount = yamlEditor.lineCount();
  for (let i = 0; i < lineCount; i++) {
    yamlEditor.removeLineClass(i, 'background', className);
  }
}

/**
 * Go to a specific line
 */
function goToLine(lineNumber) {
  if (!yamlEditor) return;

  yamlEditor.setCursor({ line: lineNumber, ch: 0 });
  yamlEditor.scrollIntoView({ line: lineNumber, ch: 0 }, 100);
  yamlEditor.focus();
}

/**
 * Find line number for a JSON path
 */
function findLineForPath(path) {
  if (!yamlEditor) return -1;

  const content = yamlEditor.getValue();
  const lines = content.split('\n');
  const pathParts = window.EditorState?.parsePath(path) || path.split('.');

  let currentIndent = 0;
  let matchedParts = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trimStart();

    if (!trimmed || trimmed.startsWith('#')) continue;

    // Calculate indent level
    const indent = line.length - trimmed.length;

    // Check if this line matches current path part
    if (matchedParts < pathParts.length) {
      const expectedKey = pathParts[matchedParts];
      const keyMatch = trimmed.match(/^([^:]+):/);

      if (keyMatch) {
        const key = keyMatch[1].trim();

        if (key === expectedKey || key === `"${expectedKey}"` || key === `'${expectedKey}'`) {
          matchedParts++;

          if (matchedParts === pathParts.length) {
            return i;
          }

          currentIndent = indent;
        }
      }
    }
  }

  return -1;
}

/**
 * Navigate to a path in the editor
 */
function goToPath(path) {
  const line = findLineForPath(path);
  if (line >= 0) {
    goToLine(line);
    return true;
  }
  return false;
}

/**
 * Refresh editor display
 */
function refreshEditor() {
  if (yamlEditor) {
    yamlEditor.refresh();
  }
  if (outputEditor) {
    outputEditor.refresh();
  }
}

/**
 * Refresh template editor display
 */
function refreshTemplateEditor() {
  if (templateEditor) {
    templateEditor.refresh();
  }
}

/**
 * Refresh rendered editor display
 */
function refreshRenderedEditor() {
  if (renderedEditor) {
    renderedEditor.refresh();
  }
}

/**
 * Refresh all editors (used when split view is resized)
 */
function refreshEditors() {
  if (yamlEditor) yamlEditor.refresh();
  if (outputEditor) outputEditor.refresh();
  if (templateEditor) templateEditor.refresh();
  if (renderedEditor) renderedEditor.refresh();
}

/**
 * Focus the YAML editor
 */
function focusEditor() {
  if (yamlEditor) {
    yamlEditor.focus();
  }
}

/**
 * Get current cursor position
 */
function getCursorPosition() {
  if (!yamlEditor) return null;
  return yamlEditor.getCursor();
}

/**
 * Check if editor has focus
 */
function hasFocus() {
  return yamlEditor && yamlEditor.hasFocus();
}

// Export for use in other modules
window.EditorCodeMirror = {
  initYamlEditor,
  initOutputEditor,
  initTemplateEditor,
  initRenderedEditor,
  setupEditorSync,
  setEditorValue,
  getEditorValue,
  setOutputValue,
  getOutputValue,
  setTemplateValue,
  getTemplateValue,
  setRenderedValue,
  getRenderedValue,
  setRenderedValueWithHighlights,
  clearRenderedHighlights,
  highlightLine,
  clearLineHighlights,
  goToLine,
  goToPath,
  findLineForPath,
  refreshEditor,
  refreshTemplateEditor,
  refreshRenderedEditor,
  refreshEditors,
  focusEditor,
  getCursorPosition,
  hasFocus
};

})(); // End IIFE
