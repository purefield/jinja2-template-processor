/**
 * Clusterfile Editor v2.0 - Help System Module
 *
 * Provides contextual help bubbles with documentation links.
 */
(function() {
'use strict';

let currentBubble = null;
let hoverTimeout = null;
const HOVER_DELAY = 300;

/**
 * Extract documentation URLs from schema field
 * Handles various formats: string, array, object, or array of objects
 */
function extractDocUrls(schema) {
  const urls = [];

  // Check x-doc-url
  if (schema['x-doc-url']) {
    const docUrl = schema['x-doc-url'];

    if (typeof docUrl === 'string') {
      urls.push({ label: 'Documentation', url: docUrl });
    } else if (Array.isArray(docUrl)) {
      for (const item of docUrl) {
        if (typeof item === 'string') {
          urls.push({ label: 'Documentation', url: item });
        } else if (typeof item === 'object') {
          for (const [label, url] of Object.entries(item)) {
            if (typeof url === 'string') {
              urls.push({ label, url });
            }
          }
        }
      }
    } else if (typeof docUrl === 'object') {
      for (const [label, url] of Object.entries(docUrl)) {
        if (typeof url === 'string') {
          urls.push({ label, url });
        }
      }
    }
  }

  // Check x-doc-urls (alternative format)
  if (schema['x-doc-urls']) {
    const docUrls = schema['x-doc-urls'];

    if (Array.isArray(docUrls)) {
      for (const item of docUrls) {
        if (typeof item === 'string') {
          urls.push({ label: 'Documentation', url: item });
        } else if (typeof item === 'object') {
          for (const [label, url] of Object.entries(item)) {
            if (typeof url === 'string') {
              urls.push({ label, url });
            }
          }
        }
      }
    } else if (typeof docUrls === 'object') {
      for (const [label, url] of Object.entries(docUrls)) {
        if (typeof url === 'string') {
          urls.push({ label, url });
        }
      }
    }
  }

  return urls;
}

/**
 * Create help bubble element
 */
function createHelpBubble(title, description, docUrls, isPinned = false) {
  const bubble = document.createElement('div');
  bubble.className = 'help-bubble';
  bubble.dataset.pinned = isPinned ? 'true' : 'false';

  let linksHtml = '';
  if (docUrls && docUrls.length > 0) {
    linksHtml = `
      <div class="help-bubble__links">
        ${docUrls.map(({ label, url }) => `
          <a href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer" class="help-bubble__link">
            ${escapeHtml(label)} ↗
          </a>
        `).join('')}
      </div>
    `;
  }

  bubble.innerHTML = `
    <div class="help-bubble__header">
      <span class="help-bubble__title">${escapeHtml(title)}</span>
      <span class="help-bubble__close" title="Close">×</span>
    </div>
    <div class="help-bubble__description">${escapeHtml(description || 'No description available.')}</div>
    ${linksHtml}
  `;

  // Close button handler
  bubble.querySelector('.help-bubble__close').addEventListener('click', (e) => {
    e.stopPropagation();
    closeBubble();
  });

  // Pin on click
  bubble.addEventListener('click', (e) => {
    if (e.target.tagName !== 'A') {
      bubble.dataset.pinned = 'true';
    }
  });

  return bubble;
}

/**
 * Position bubble near target element
 */
function positionBubble(bubble, targetElement) {
  const rect = targetElement.getBoundingClientRect();
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;

  // Start with position below and to the right of the target
  let left = rect.right + 8;
  let top = rect.top;

  // Add bubble to DOM temporarily to measure it
  bubble.style.visibility = 'hidden';
  document.body.appendChild(bubble);
  const bubbleRect = bubble.getBoundingClientRect();

  // Adjust if bubble goes off right edge
  if (left + bubbleRect.width > viewportWidth - 16) {
    left = rect.left - bubbleRect.width - 8;
  }

  // Adjust if bubble goes off left edge
  if (left < 16) {
    left = 16;
  }

  // Adjust if bubble goes off bottom
  if (top + bubbleRect.height > viewportHeight - 16) {
    top = viewportHeight - bubbleRect.height - 16;
  }

  // Adjust if bubble goes off top
  if (top < 16) {
    top = 16;
  }

  bubble.style.left = `${left}px`;
  bubble.style.top = `${top}px`;
  bubble.style.visibility = 'visible';
}

/**
 * Show help bubble for a schema field
 */
function showHelpBubble(targetElement, fieldSchema, fieldName) {
  closeBubble();

  const title = fieldSchema.title || fieldName || 'Field';
  const description = fieldSchema.description || '';
  const docUrls = extractDocUrls(fieldSchema);

  const bubble = createHelpBubble(title, description, docUrls);
  positionBubble(bubble, targetElement);

  // Keep bubble open when mouse is over it
  bubble.addEventListener('mouseenter', () => {
    clearTimeout(hoverTimeout);
  });

  bubble.addEventListener('mouseleave', () => {
    clearTimeout(hoverTimeout);
    hoverTimeout = setTimeout(() => {
      closeBubbleIfNotPinned();
    }, 200);
  });

  currentBubble = bubble;
}

/**
 * Close current bubble
 */
function closeBubble() {
  if (currentBubble) {
    currentBubble.remove();
    currentBubble = null;
  }
  clearTimeout(hoverTimeout);
}

/**
 * Close bubble if not pinned
 */
function closeBubbleIfNotPinned() {
  if (currentBubble && currentBubble.dataset.pinned !== 'true') {
    closeBubble();
  }
}

/**
 * Setup help icon hover behavior
 */
function setupHelpIcon(helpIcon, fieldSchema, fieldName) {
  helpIcon.addEventListener('mouseenter', () => {
    clearTimeout(hoverTimeout);
    hoverTimeout = setTimeout(() => {
      showHelpBubble(helpIcon, fieldSchema, fieldName);
    }, HOVER_DELAY);
  });

  helpIcon.addEventListener('mouseleave', (e) => {
    clearTimeout(hoverTimeout);
    // Give time for mouse to reach the bubble
    hoverTimeout = setTimeout(() => {
      // Only close if mouse is not over the bubble
      if (currentBubble && !currentBubble.matches(':hover')) {
        closeBubbleIfNotPinned();
      }
    }, 300);
  });
}

/**
 * Create a help icon element
 */
function createHelpIcon(fieldSchema, fieldName) {
  const icon = document.createElement('span');
  icon.className = 'form-label__help';
  icon.innerHTML = '?';
  icon.title = 'Click for help';

  setupHelpIcon(icon, fieldSchema, fieldName);

  return icon;
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Close bubble when clicking outside
document.addEventListener('click', (e) => {
  if (currentBubble && !currentBubble.contains(e.target)) {
    const helpIcons = document.querySelectorAll('.form-label__help');
    let clickedHelpIcon = false;
    helpIcons.forEach(icon => {
      if (icon.contains(e.target)) {
        clickedHelpIcon = true;
      }
    });
    if (!clickedHelpIcon) {
      closeBubble();
    }
  }
});

// Close bubble on escape
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeBubble();
  }
});

// Export for use in other modules
window.EditorHelp = {
  showHelpBubble,
  closeBubble,
  createHelpIcon,
  extractDocUrls,
  escapeHtml
};

})(); // End IIFE
