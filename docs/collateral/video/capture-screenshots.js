/**
 * Playwright screenshot capture for Clusterfile video presentation.
 * Captures 6 real screenshots from the running editor at localhost:8000.
 *
 * Usage (inside Playwright container):
 *   node capture-screenshots.js
 *
 * Or with npx:
 *   npx playwright install chromium && node capture-screenshots.js
 */

const { chromium } = require('playwright');
const path = require('path');

const OUTPUT_DIR = process.env.OUTPUT_DIR || path.join(__dirname, 'screenshots');
const EDITOR_URL = process.env.EDITOR_URL || 'http://localhost:8000';
const VIEWPORT = { width: 1920, height: 1080 };

async function delay(ms) { return new Promise(r => setTimeout(r, ms)); }

async function dismissModals(page) {
  // Dismiss the welcome tour modal and any other overlays
  try {
    const tourBtn = await page.$('#tour-close');
    if (tourBtn && await tourBtn.isVisible()) {
      await tourBtn.click();
      await delay(500);
      return;
    }
    const closeBtn = await page.$('.modal__close');
    if (closeBtn && await closeBtn.isVisible()) {
      await closeBtn.click();
      await delay(500);
    }
  } catch (e) { /* no modal */ }
}

async function loadSample(page, filename) {
  await page.evaluate(async (fn) => {
    const res = await fetch(`/api/samples/${fn}`);
    const data = await res.json();
    window.ClusterfileEditor.loadDocument(data.content, data.filename, true);
  }, filename);
  await delay(800);
  await dismissModals(page);
}

async function selectSection(page, section) {
  await page.click(`[data-section="${section}"]`);
  await delay(500);
}

async function renderTemplate(page, templateName) {
  await selectSection(page, 'templates');
  await delay(300);
  await page.selectOption('#template-select', templateName);
  await delay(300);
  await page.click('.tab[data-tab="rendered"]');
  await delay(1200);
}

async function screenshot(page, name) {
  const filepath = path.join(OUTPUT_DIR, `${name}.png`);
  await page.screenshot({ path: filepath, type: 'png' });
  console.log(`  -> ${filepath}`);
}

(async () => {
  console.log('Launching Chromium...');
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: VIEWPORT });
  const page = await context.newPage();

  console.log(`Navigating to ${EDITOR_URL}...`);
  await page.goto(EDITOR_URL, { waitUntil: 'networkidle' });
  await delay(1500);
  await dismissModals(page);
  await delay(500);

  // --- Screenshot 1: Load baremetal sample ---
  console.log('1/6  Loading baremetal sample...');
  await loadSample(page, 'baremetal-bond.clusterfile');
  await selectSection(page, 'cluster');
  await delay(500);
  await screenshot(page, '01-baremetal-loaded');

  // --- Screenshot 2: Change platform to kubevirt ---
  console.log('2/6  Switching to kubevirt...');
  await loadSample(page, 'kubevirt.clusterfile');
  await selectSection(page, 'cluster');
  await delay(500);
  await screenshot(page, '02-kubevirt-platform');

  // --- Screenshot 3: Enable operators ---
  console.log('3/6  Enabling operators...');
  await loadSample(page, 'baremetal-bond.clusterfile');
  await selectSection(page, 'plugins');
  await delay(800);
  await screenshot(page, '03-operators-enabled');

  // --- Screenshot 4: Render install-config ---
  console.log('4/6  Rendering install-config...');
  await renderTemplate(page, 'install-config.yaml.tpl');
  await screenshot(page, '04-render-install-config');

  // --- Screenshot 5: Render operators ---
  console.log('5/6  Rendering operators...');
  await renderTemplate(page, 'operators.yaml.tpl');
  await screenshot(page, '05-render-operators');

  // --- Screenshot 6: Render siteconfig ---
  console.log('6/6  Rendering siteconfig...');
  await renderTemplate(page, 'clusterfile2siteconfig.yaml.tpl');
  await screenshot(page, '06-render-siteconfig');

  await browser.close();
  console.log('Done — 6 screenshots captured.');
})();
