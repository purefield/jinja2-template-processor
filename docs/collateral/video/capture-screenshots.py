#!/usr/bin/env python3
"""Capture editor screenshots using Playwright (Python)."""

import asyncio
import os
from pathlib import Path
from playwright.async_api import async_playwright

OUTPUT_DIR = Path(__file__).resolve().parent / "screenshots"
EDITOR_URL = os.environ.get("EDITOR_URL", "http://localhost:8000")
VIEWPORT = {"width": 1920, "height": 1080}

async def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(viewport=VIEWPORT)
        page = await context.new_page()

        print(f"Navigating to {EDITOR_URL}...")
        await page.goto(EDITOR_URL, wait_until="networkidle")
        await page.wait_for_timeout(1500)

        # 1. Load baremetal sample
        print("1/6  Loading baremetal sample...")
        await page.evaluate("""async () => {
            const res = await fetch('/api/samples/baremetal-bond.clusterfile');
            const data = await res.json();
            window.ClusterfileEditor.loadDocument(data.content, data.filename, true);
        }""")
        await page.wait_for_timeout(1000)
        await page.click('[data-section="cluster"]')
        await page.wait_for_timeout(500)
        await page.screenshot(path=str(OUTPUT_DIR / "01-baremetal-loaded.png"))
        print("  -> 01-baremetal-loaded.png")

        # 2. Switch to kubevirt
        print("2/6  Switching to kubevirt...")
        await page.evaluate("""async () => {
            const res = await fetch('/api/samples/kubevirt.clusterfile');
            const data = await res.json();
            window.ClusterfileEditor.loadDocument(data.content, data.filename, true);
        }""")
        await page.wait_for_timeout(1000)
        await page.click('[data-section="cluster"]')
        await page.wait_for_timeout(500)
        await page.screenshot(path=str(OUTPUT_DIR / "02-kubevirt-platform.png"))
        print("  -> 02-kubevirt-platform.png")

        # 3. Enable operators (reload baremetal, show plugins)
        print("3/6  Showing operators...")
        await page.evaluate("""async () => {
            const res = await fetch('/api/samples/baremetal-bond.clusterfile');
            const data = await res.json();
            window.ClusterfileEditor.loadDocument(data.content, data.filename, true);
        }""")
        await page.wait_for_timeout(1000)
        await page.click('[data-section="plugins"]')
        await page.wait_for_timeout(800)
        await page.screenshot(path=str(OUTPUT_DIR / "03-operators-enabled.png"))
        print("  -> 03-operators-enabled.png")

        # 4. Render install-config
        print("4/6  Rendering install-config...")
        await page.click('[data-section="templates"]')
        await page.wait_for_timeout(500)
        await page.selectOption('#template-select', 'install-config.yaml.tpl')
        await page.wait_for_timeout(300)
        await page.click('.tab[data-tab="rendered"]')
        await page.wait_for_timeout(1500)
        await page.screenshot(path=str(OUTPUT_DIR / "04-render-install-config.png"))
        print("  -> 04-render-install-config.png")

        # 5. Render operators
        print("5/6  Rendering operators...")
        await page.selectOption('#template-select', 'operators.yaml.tpl')
        await page.wait_for_timeout(300)
        await page.click('.tab[data-tab="rendered"]')
        await page.wait_for_timeout(1500)
        await page.screenshot(path=str(OUTPUT_DIR / "05-render-operators.png"))
        print("  -> 05-render-operators.png")

        # 6. Render siteconfig
        print("6/6  Rendering siteconfig...")
        await page.selectOption('#template-select', 'clusterfile2siteconfig.yaml.tpl')
        await page.wait_for_timeout(300)
        await page.click('.tab[data-tab="rendered"]')
        await page.wait_for_timeout(1500)
        await page.screenshot(path=str(OUTPUT_DIR / "06-render-siteconfig.png"))
        print("  -> 06-render-siteconfig.png")

        await browser.close()
        print("Done — 6 screenshots captured.")

if __name__ == "__main__":
    asyncio.run(main())
