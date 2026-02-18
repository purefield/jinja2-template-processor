#!/usr/bin/env python3
"""
Clusterfile Presentation Video Generator
=========================================
Generates a ~3-minute narrated MP4 video from:
  - Real editor screenshots (captured by capture-screenshots.js)
  - SVG diagrams (architecture.svg, infographic.svg)
  - Generated Pillow slide images (title, data, CTA)
  - Edge-TTS narration audio

Dependencies: pip install edge-tts moviepy Pillow
Optional:     pip install cairosvg (for SVG rendering, needs libcairo)

Usage:
  python generate-video.py                       # full pipeline
  python generate-video.py --slides-only         # just generate slide PNGs
  python generate-video.py --audio-only          # just generate TTS audio
  python generate-video.py --skip-screenshots    # skip screenshots, use existing
"""

import asyncio
import argparse
import os
import sys
import glob as globmod
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
try:
    import cairosvg
    HAS_CAIROSVG = True
except (ImportError, OSError):
    HAS_CAIROSVG = False

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
COLLATERAL = HERE.parent
REPO_ROOT = COLLATERAL.parent.parent
SCREENSHOTS_DIR = HERE / "screenshots"
SLIDES_DIR = HERE / "slides"
AUDIO_DIR = HERE / "audio"
OUTPUT_FILE = HERE / "clusterfile-presentation.mp4"

W, H = 1920, 1080

# ---------------------------------------------------------------------------
# Colour palette (matches deck / SVGs)
# ---------------------------------------------------------------------------
BG_DARK = (13, 71, 161)       # #0d47a1
BG_LIGHT = (248, 249, 250)    # #f8f9fa
WHITE = (255, 255, 255)
BLACK = (33, 33, 33)           # #212121
BLUE = (21, 101, 192)         # #1565c0
RED = (198, 40, 40)           # #c62828
GREEN = (46, 125, 50)         # #2e7d32
ORANGE = (230, 81, 0)         # #e65100
PURPLE = (106, 27, 154)       # #6a1b9a
GREY = (117, 117, 117)        # #757575
LIGHT_GREY = (224, 224, 224)  # #e0e0e0
CARD_BG = (227, 242, 253)     # #e3f2fd

# ---------------------------------------------------------------------------
# Font helpers
# ---------------------------------------------------------------------------
_font_cache = {}

def _find_font():
    """Find a usable sans-serif font on the system."""
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/usr/share/fonts/google-noto/NotoSans-Regular.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return None

def _find_bold_font():
    """Find a usable bold sans-serif font on the system."""
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/google-noto/NotoSans-Bold.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return _find_font()  # fallback to regular

FONT_PATH = _find_font()
BOLD_FONT_PATH = _find_bold_font()

def font(size, bold=False):
    key = (size, bold)
    if key not in _font_cache:
        path = BOLD_FONT_PATH if bold else FONT_PATH
        if path:
            _font_cache[key] = ImageFont.truetype(path, size)
        else:
            _font_cache[key] = ImageFont.load_default()
    return _font_cache[key]

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------
def new_slide(bg=BG_LIGHT):
    img = Image.new("RGB", (W, H), bg)
    return img, ImageDraw.Draw(img)

def draw_centred(draw, y, text, fnt, fill=BLACK):
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw = bbox[2] - bbox[0]
    draw.text(((W - tw) // 2, y), text, font=fnt, fill=fill)

def draw_left(draw, x, y, text, fnt, fill=BLACK):
    draw.text((x, y), text, font=fnt, fill=fill)

def draw_card(draw, x, y, w, h, fill=WHITE, outline=LIGHT_GREY, radius=16):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=fill, outline=outline, width=2)

def draw_bar(draw, x, y, w, h, fill=BLUE, radius=6):
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=fill)

def draw_footer(draw, text="Clusterfile v3.5.0 — quay.io/dds/clusterfile-editor:latest"):
    draw_centred(draw, H - 50, text, font(18), GREY)

# ---------------------------------------------------------------------------
# Slide generators
# ---------------------------------------------------------------------------
def slide_title():
    """Slide 1: Title card."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 280, "Clusterfile", font(96, bold=True), WHITE)
    draw_centred(draw, 400, "One definition, every deployment method", font(36), (187, 222, 251))
    draw_centred(draw, 500, "A declarative cluster intent format + template processor + web editor", font(24), (144, 202, 249))
    draw_centred(draw, 560, "for OpenShift", font(24), (144, 202, 249))
    draw_centred(draw, 680, "v3.5.0", font(28, bold=True), (200, 230, 255))
    return img

def slide_problem():
    """Slide 2: The problem — config sprawl."""
    img, draw = new_slide()
    draw_centred(draw, 60, "The Problem: Configuration Sprawl", font(52, bold=True), BG_DARK)
    draw_centred(draw, 140, "One cluster, five files, five formats", font(28), GREY)

    # Draw file boxes
    files = [
        ("install-config.yaml", "IPI / ABI", BLUE),
        ("agent-config.yaml", "Agent-based", BLUE),
        ("ACM ZTP (5 CRs)", "Fleet mgmt", RED),
        ("SiteConfig CR", "ClusterInstance", ORANGE),
        ("operators.yaml", "6 subscriptions", PURPLE),
    ]
    box_w, box_h, gap = 320, 160, 30
    total_w = len(files) * box_w + (len(files) - 1) * gap
    start_x = (W - total_w) // 2
    for i, (name, desc, colour) in enumerate(files):
        x = start_x + i * (box_w + gap)
        y = 240
        draw_card(draw, x, y, box_w, box_h, WHITE, colour)
        draw_centred(draw, y + 30, name, font(22, bold=True), colour)
        draw_centred(draw, y + 70, desc, font(18), GREY)

    # Pain points
    pains = [
        "Each file has its own format, its own assumptions, its own gotchas",
        "A single network change touches 3+ files",
        "No cross-file validation — mismatches cause silent failures",
        "Copy-paste between clusters drifts over time",
    ]
    for i, pain in enumerate(pains):
        # Recenter pain text
        bbox = draw.textbbox((0, 0), pain, font=font(22))
        tw = bbox[2] - bbox[0]
        draw_left(draw, max(120, (W - tw) // 2), 480 + i * 55, f"•  {pain}", font(22), BLACK)

    draw_centred(draw, 740, "Result: Fragile installs, slow onboarding, tribal knowledge", font(26, bold=True), RED)
    draw_centred(draw, 820, "\"We spent 4 hours debugging a network mismatch between install-config and agent-config\"", font(20), GREY)
    draw_footer(draw)
    return img

def slide_insight():
    """Slide 3: The insight — same data, different formats."""
    img, draw = new_slide()
    draw_centred(draw, 60, "The Insight", font(52, bold=True), BG_DARK)
    draw_centred(draw, 140, "Same data, different formats", font(28), GREY)

    # Table header
    cols = ["Data", "install-config", "ACM ZTP", "SiteConfig", "operators"]
    col_x = [200, 520, 730, 920, 1120]
    y_start = 260
    row_h = 60
    for i, col in enumerate(cols):
        draw_left(draw, col_x[i], y_start, col, font(22, bold=True), BG_DARK)
    draw.line([(180, y_start + 35), (1350, y_start + 35)], fill=LIGHT_GREY, width=2)

    rows = [
        ("Cluster name", True, True, True, True),
        ("Network config", True, True, True, False),
        ("Host BMC creds", False, True, True, False),
        ("Platform details", True, True, True, False),
        ("Operator config", False, False, False, True),
    ]
    for j, (label, *checks) in enumerate(rows):
        y = y_start + 50 + j * row_h
        draw_left(draw, col_x[0], y, label, font(22), BLACK)
        for k, v in enumerate(checks):
            marker = "Yes" if v else "—"
            color = GREEN if v else LIGHT_GREY
            draw_left(draw, col_x[k + 1] + 30, y, marker, font(22, bold=True), color)

    draw_centred(draw, 640, "The cluster intent is constant.", font(30, bold=True), BG_DARK)
    draw_centred(draw, 700, "Only the output format changes.", font(30), BLUE)
    draw_footer(draw)
    return img

def slide_solution():
    """Slide 4: The solution — one file, many outputs."""
    img, draw = new_slide()
    draw_centred(draw, 60, "The Solution", font(52, bold=True), BG_DARK)
    draw_centred(draw, 140, "One YAML file, 102 templates, any output format", font(28), GREY)

    # Central clusterfile box
    cx, cy, cw, ch = 660, 300, 600, 200
    draw_card(draw, cx, cy, cw, ch, BG_DARK, BG_DARK)
    draw_centred(draw, cy + 30, "clusterfile.yaml", font(36, bold=True), WHITE)
    draw_centred(draw, cy + 90, "cluster | network | hosts | plugins", font(22), (187, 222, 251))
    draw_centred(draw, cy + 130, "Schema-validated  •  File references for secrets", font(20), (144, 202, 249))

    # Output arrows
    outputs = [
        ("install-config.yaml", "(IPI / ABI)", BLUE),
        ("agent-config.yaml", "(agent-based)", BLUE),
        ("ACM ZTP manifests", "(5 CRs, 32 resources)", RED),
        ("SiteConfig CR", "(ClusterInstance)", ORANGE),
        ("operators.yaml", "(6 subscriptions)", PURPLE),
        ("pre-check.sh", "(DNS, NTP, BMC)", GREEN),
    ]
    start_y = 580
    for i, (name, detail, colour) in enumerate(outputs):
        x = 140 + i * 280
        y = start_y
        # Arrow from center
        draw.line([(W // 2, cy + ch), (x + 120, y)], fill=colour, width=2)
        draw_card(draw, x, y, 250, 80, WHITE, colour)
        draw_left(draw, x + 15, y + 12, name, font(18, bold=True), colour)
        draw_left(draw, x + 15, y + 42, detail, font(16), GREY)

    draw_centred(draw, 720, "Define once  →  Render many  →  Validate always", font(26, bold=True), GREEN)
    draw_footer(draw)
    return img

def slide_file_externalization():
    """Slide 5: File externalization."""
    img, draw = new_slide()
    draw_centred(draw, 60, "File Externalization", font(52, bold=True), BG_DARK)
    draw_centred(draw, 140, "Secrets and large content are file paths, not inline blobs", font(28), GREY)

    # File path examples
    refs = [
        ("pullSecret:", "~/pull-secret.json", "3 KB JSON auth blob"),
        ("sshKeys:", "~/.ssh/id_ed25519.pub", "SSH public key"),
        ("trustBundle:", "~/ca-bundle.pem", "4 KB certificate chain"),
        ("bmc.password:", "~/bmc.pass", "BMC credentials"),
        ("credentials:", "~/cloud-creds.json", "Cloud provider auth"),
    ]
    y = 260
    for field, path, desc in refs:
        draw_left(draw, 200, y, field, font(26, bold=True), PURPLE)
        draw_left(draw, 530, y, path, font(26), BLUE)
        draw_left(draw, 1050, y, f"→  {desc}", font(22), GREY)
        y += 65

    # Separator
    draw.line([(200, y + 10), (W - 200, y + 10)], fill=LIGHT_GREY, width=2)

    # Explanation
    draw_centred(draw, y + 50, "load_file() reads content at render time", font(26, bold=True), BG_DARK)
    draw_centred(draw, y + 100, "Clusterfile stays compact, readable, and safe to commit", font(24), GREY)

    # Day-2 box
    draw_card(draw, 300, y + 170, W - 600, 120, (243, 229, 245), PURPLE)
    draw_centred(draw, y + 195, "Day-2: Vault / OpenBao  →  External Secrets Operator  →  K8s Secrets", font(24, bold=True), PURPLE)
    draw_centred(draw, y + 240, "Templates generate ESO manifests; ESO runs on the created cluster", font(20), GREY)

    draw_footer(draw)
    return img

def slide_numbers():
    """Slide 12: The numbers — expansion ratios."""
    img, draw = new_slide()
    draw_centred(draw, 60, "The Numbers", font(52, bold=True), BG_DARK)
    draw_centred(draw, 140, "Real data from production clusterfiles", font(28), GREY)

    # Three big ratio cards
    ratios = [
        ("9.7x", "Lines of code", "267 → 2,579 output lines", BLUE, CARD_BG),
        ("5.6x", "Data fields", "187 → 1,049 output fields", ORANGE, (255, 243, 224)),
        ("56", "K8s resources (ZTP)", "17 top-level + 39 nested", PURPLE, (243, 229, 245)),
    ]
    card_w, card_h = 500, 260
    gap = 50
    total = len(ratios) * card_w + (len(ratios) - 1) * gap
    sx = (W - total) // 2
    for i, (big, label, detail, colour, bg) in enumerate(ratios):
        x = sx + i * (card_w + gap)
        y = 240
        draw_card(draw, x, y, card_w, card_h, bg, colour)
        draw_centred(draw, y + 30, big, font(72, bold=True), colour)
        draw_centred(draw, y + 130, label, font(26, bold=True), BLACK)
        draw_centred(draw, y + 175, detail, font(22), GREY)

    # Bar chart mini
    bars = [
        ("ACM ZTP", 648, RED),
        ("agent-config", 245, RED),
        ("SiteConfig", 151, ORANGE),
        ("install-config", 106, RED),
        ("operators", 50, RED),
    ]
    bar_y = 580
    max_w = 900
    max_val = 648
    draw_centred(draw, bar_y - 30, "Output fields per template (baremetal 3-node HA)", font(24, bold=True), BLACK)
    for i, (name, val, colour) in enumerate(bars):
        y = bar_y + i * 55
        draw_left(draw, 200, y + 5, name, font(20), BLACK)
        bw = int(val / max_val * max_w)
        draw_bar(draw, 450, y, bw, 35, colour)
        draw_left(draw, 460 + bw, y + 5, str(val), font(20, bold=True), colour)

    draw_footer(draw)
    return img

def slide_time_cost():
    """Slide 13: Time & cost comparison."""
    img, draw = new_slide()
    draw_centred(draw, 60, "Time & Cost: Manual vs. Clusterfile", font(48, bold=True), BG_DARK)
    draw_centred(draw, 130, "Baremetal 3-node cluster, 2,579 lines of config, $150/hr consultant rate", font(22), GREY)

    # Table
    headers = ["Scenario", "Manual", "Clusterfile", "Savings"]
    hx = [200, 550, 850, 1200]
    hy = 220
    for i, h in enumerate(headers):
        draw_left(draw, hx[i], hy, h, font(24, bold=True), BG_DARK)
    draw.line([(180, hy + 35), (1500, hy + 35)], fill=LIGHT_GREY, width=2)

    rows = [
        ("First cluster", "6 hours / $900", "30 min / $75", "92% / $825"),
        ("Next cluster", "3 hours / $450", "15 min / $38", "92% / $412"),
        ("Switch method", "4 hours / $600", "1 min / $2.50", "99% / $598"),
        ("10 clusters", "33 hours / $4,950", "3 hours / $450", "91% / $4,500"),
    ]
    for j, (scenario, manual, cf, savings) in enumerate(rows):
        y = hy + 55 + j * 80
        bg = (250, 250, 250) if j % 2 == 0 else WHITE
        draw.rectangle([(180, y - 5), (1500, y + 50)], fill=bg)
        draw_left(draw, hx[0], y + 5, scenario, font(24, bold=True), BLACK)
        draw_left(draw, hx[1], y + 5, manual, font(24), RED)
        draw_left(draw, hx[2], y + 5, cf, font(24), GREEN)
        draw_left(draw, hx[3], y + 5, savings, font(24, bold=True), BLUE)

    draw.line([(180, hy + 55 + len(rows) * 80), (1500, hy + 55 + len(rows) * 80)], fill=LIGHT_GREY, width=2)
    draw_centred(draw, 640, "Time freed goes to architecture, migration, and higher-value work", font(24, bold=True), GREEN)

    # Bottom stat boxes
    stats = [
        ("92%", "savings on\nfirst cluster"),
        ("$4,500", "saved on a\n10-cluster engagement"),
        ("1 min", "to switch\ndeployment method"),
    ]
    box_w = 380
    gap = 60
    sx = (W - (3 * box_w + 2 * gap)) // 2
    for i, (big, detail) in enumerate(stats):
        x = sx + i * (box_w + gap)
        y = 730
        draw_card(draw, x, y, box_w, 180, CARD_BG, BLUE)
        draw_centred(draw, y + 20, big, font(56, bold=True), BLUE)
        for k, line in enumerate(detail.split("\n")):
            draw_centred(draw, y + 100 + k * 30, line, font(22), GREY)

    draw_footer(draw)
    return img

def slide_platform_coverage():
    """Slide 14: Platform coverage."""
    img, draw = new_slide()
    draw_centred(draw, 60, "Platform Coverage", font(52, bold=True), BG_DARK)
    draw_centred(draw, 140, "11 platforms, 6 deployment methods, 134 tests", font(28), GREY)

    # Platform grid
    platforms = [
        ("Public Cloud", ["AWS", "Azure", "GCP", "IBM Cloud"], BLUE),
        ("On-Premises", ["vSphere", "Nutanix", "OpenStack"], ORANGE),
        ("Specialized", ["Baremetal", "KubeVirt", "SNO", "External"], PURPLE),
    ]
    sy = 250
    for group, items, colour in platforms:
        draw_left(draw, 200, sy, group, font(28, bold=True), colour)
        for i, item in enumerate(items):
            x = 500 + i * 250
            draw_card(draw, x, sy - 10, 210, 50, WHITE, colour)
            draw_left(draw, x + 20, sy, item, font(22), colour)
        sy += 100

    # Deployment methods
    draw.line([(200, sy + 10), (W - 200, sy + 10)], fill=LIGHT_GREY, width=2)
    sy += 50
    draw_left(draw, 200, sy, "Deployment methods:", font(28, bold=True), BG_DARK)
    methods = ["Agent-based", "IPI", "ACM ZTP", "ACM CAPI", "UPI", "SiteConfig"]
    for i, m in enumerate(methods):
        x = 200 + i * 260
        draw_card(draw, x, sy + 50, 230, 50, CARD_BG, BLUE)
        draw_left(draw, x + 20, sy + 60, m, font(20), BLUE)

    # Operator plugins
    sy += 160
    draw_left(draw, 200, sy, "Operator plugins:", font(28, bold=True), BG_DARK)
    operators = ["ArgoCD", "LVM Storage", "ODF", "ACM", "cert-manager", "external-secrets"]
    for i, op in enumerate(operators):
        x = 200 + i * 260
        draw_card(draw, x, sy + 50, 230, 50, (255, 243, 224), ORANGE)
        draw_left(draw, x + 20, sy + 60, op, font(20), ORANGE)

    # Test coverage
    sy += 160
    draw_centred(draw, sy, "134 automated tests — every platform × method × operator combination", font(24, bold=True), GREEN)

    draw_footer(draw)
    return img

def slide_cta():
    """Slide 15: Call to action."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 120, "Try It Now", font(64, bold=True), WHITE)
    draw_centred(draw, 220, "One container, one command", font(32), (187, 222, 251))

    # Container command card
    draw_card(draw, 300, 320, W - 600, 100, (30, 30, 30), (100, 100, 100))
    draw_centred(draw, 345, "podman run -d -p 8000:8000 quay.io/dds/clusterfile-editor:v3.5.0", font(28), (100, 255, 100))

    # CLI command card
    draw_card(draw, 300, 470, W - 600, 100, (30, 30, 30), (100, 100, 100))
    draw_centred(draw, 495, "python process.py -t install-config.yaml.tpl -d data/baremetal.clusterfile", font(24), (100, 255, 100))

    # Steps
    steps = [
        "1.  Pull the container and open localhost:8000",
        "2.  Load a sample clusterfile — try baremetal or kubevirt",
        "3.  Change platform, enable operators, render different outputs",
        "4.  Download your clusterfile and use the CLI in your pipeline",
    ]
    sy = 640
    for step in steps:
        draw_centred(draw, sy, step, font(24), (200, 230, 255))
        sy += 50

    draw_centred(draw, 900, "quay.io/dds/clusterfile-editor:latest", font(22), GREY)
    return img

def slide_end():
    """Slide 16: End card."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 320, "Clusterfile", font(72, bold=True), WHITE)
    draw_centred(draw, 430, "v3.5.0", font(36), (187, 222, 251))
    draw_centred(draw, 530, "quay.io/dds/clusterfile-editor:latest", font(28), (144, 202, 249))
    draw_centred(draw, 620, "102 templates  |  11 platforms  |  6 operators  |  134 tests", font(24), GREY)
    return img

# ---------------------------------------------------------------------------
# SVG → PNG conversion
# ---------------------------------------------------------------------------
def svg_to_slide(svg_path, output_path):
    """Convert an SVG to a 1920x1080 PNG slide with white background."""
    if not HAS_CAIROSVG:
        return None
    import io
    png_data = cairosvg.svg2png(url=str(svg_path), output_width=1600)
    overlay = Image.open(io.BytesIO(png_data)).convert("RGBA")

    bg = Image.new("RGB", (W, H), BG_LIGHT)
    ow, oh = overlay.size
    if oh > H - 40:
        ratio = (H - 40) / oh
        overlay = overlay.resize((int(ow * ratio), int(oh * ratio)), Image.LANCZOS)
        ow, oh = overlay.size
    ox = (W - ow) // 2
    oy = (H - oh) // 2
    bg.paste(overlay, (ox, oy), overlay)
    bg.save(str(output_path))
    return str(output_path)

# ---------------------------------------------------------------------------
# Screenshot → slide (add subtle border / branding)
# ---------------------------------------------------------------------------
def screenshot_to_slide(screenshot_path, output_path):
    """Wrap a screenshot in a 1920x1080 frame."""
    if not os.path.exists(screenshot_path):
        print(f"  [WARN] Screenshot not found: {screenshot_path}, generating placeholder")
        img, draw = new_slide()
        draw_centred(draw, H // 2 - 30, f"[Screenshot: {Path(screenshot_path).stem}]", font(36, bold=True), GREY)
        draw_centred(draw, H // 2 + 30, "Live editor screenshot placeholder", font(24), GREY)
        img.save(str(output_path))
        return str(output_path)

    shot = Image.open(screenshot_path).convert("RGB")
    # Resize to fit within frame with 4px border
    shot = shot.resize((W - 8, H - 8), Image.LANCZOS)
    bg = Image.new("RGB", (W, H), (60, 60, 60))
    bg.paste(shot, (4, 4))
    bg.save(str(output_path))
    return str(output_path)

# ---------------------------------------------------------------------------
# Generate all slides
# ---------------------------------------------------------------------------
def generate_slides():
    """Generate all slide PNG images."""
    SLIDES_DIR.mkdir(parents=True, exist_ok=True)
    slides = []

    print("Generating slides...")

    # 1. Title
    slide_title().save(str(SLIDES_DIR / "01-title.png"))
    slides.append("01-title.png")
    print("  01-title")

    # 2. Problem
    slide_problem().save(str(SLIDES_DIR / "02-problem.png"))
    slides.append("02-problem.png")
    print("  02-problem")

    # 3. Insight
    slide_insight().save(str(SLIDES_DIR / "03-insight.png"))
    slides.append("03-insight.png")
    print("  03-insight")

    # 4. Solution
    slide_solution().save(str(SLIDES_DIR / "04-solution.png"))
    slides.append("04-solution.png")
    print("  04-solution")

    # 5. File externalization
    slide_file_externalization().save(str(SLIDES_DIR / "05-file-ext.png"))
    slides.append("05-file-ext.png")
    print("  05-file-ext")

    # 6-11. Demo screenshots
    screenshot_names = [
        ("06-demo-baremetal", "01-baremetal-loaded"),
        ("07-demo-kubevirt", "02-kubevirt-platform"),
        ("08-demo-operators", "03-operators-enabled"),
        ("09-demo-install-config", "04-render-install-config"),
        ("10-demo-operators-render", "05-render-operators"),
        ("11-demo-siteconfig", "06-render-siteconfig"),
    ]
    for slide_name, shot_name in screenshot_names:
        src = SCREENSHOTS_DIR / f"{shot_name}.png"
        dst = SLIDES_DIR / f"{slide_name}.png"
        screenshot_to_slide(str(src), str(dst))
        slides.append(f"{slide_name}.png")
        print(f"  {slide_name}")

    # 12. Numbers
    slide_numbers().save(str(SLIDES_DIR / "12-numbers.png"))
    slides.append("12-numbers.png")
    print("  12-numbers")

    # 13. Time & cost
    slide_time_cost().save(str(SLIDES_DIR / "13-time-cost.png"))
    slides.append("13-time-cost.png")
    print("  13-time-cost")

    # 14. Platform coverage (from architecture SVG if cairosvg available, else Pillow)
    arch_svg = COLLATERAL / "architecture.svg"
    rendered = None
    if arch_svg.exists() and HAS_CAIROSVG:
        rendered = svg_to_slide(arch_svg, SLIDES_DIR / "14-architecture.png")
    if not rendered:
        slide_platform_coverage().save(str(SLIDES_DIR / "14-architecture.png"))
    slides.append("14-architecture.png")
    print("  14-architecture")

    # 15. CTA
    slide_cta().save(str(SLIDES_DIR / "15-cta.png"))
    slides.append("15-cta.png")
    print("  15-cta")

    # 16. End card
    slide_end().save(str(SLIDES_DIR / "16-end.png"))
    slides.append("16-end.png")
    print("  16-end")

    print(f"Generated {len(slides)} slides in {SLIDES_DIR}")
    return slides

# ---------------------------------------------------------------------------
# Narration text per section
# ---------------------------------------------------------------------------
NARRATION = [
    # (slide_name, text, min_duration_seconds)
    ("01-title", "", 5),
    ("02-problem",
     "Deploying an OpenShift cluster requires five or more configuration files, "
     "each with its own format and its own assumptions. A single network change "
     "touches three files. Mismatches cause silent failures that take hours to debug.",
     15),
    ("03-insight",
     "The insight is simple: the cluster intent is always the same. "
     "Cluster name, network config, host details, operator settings. "
     "Only the output format changes.",
     10),
    ("04-solution",
     "One YAML file. 102 Jinja2 templates. Any output format. "
     "Define once, render many, validate always. "
     "The clusterfile is schema-validated before a single template runs.",
     12),
    ("05-file-ext",
     "Secrets and large content are file paths, not inline blobs. "
     "Pull secrets, SSH keys, certificates, and BMC credentials stay on disk. "
     "The processor reads and inlines them at render time. "
     "Your clusterfile stays compact, readable, and safe to commit.",
     10),
    ("06-demo-baremetal",
     "Here's a baremetal cluster loaded in the web editor. "
     "The form is auto-generated from the JSON schema. "
     "Every field has validation, every section is collapsible.",
     12),
    ("07-demo-kubevirt",
     "Change the platform to KubeVirt and the schema adapts instantly. "
     "BMC fields disappear. KubeVirt-specific options appear. "
     "The form always shows exactly what this platform needs.",
     12),
    ("08-demo-operators",
     "Enable operators with a toggle. Smart defaults fill in. "
     "cert-manager, external-secrets, LVM storage. "
     "Each operator plugin adds its own schema and templates.",
     10),
    ("09-demo-install-config",
     "Render install-config, the output the OpenShift installer expects. "
     "Platform stanza, networking, pull secret, SSH keys. "
     "All cross-referenced from the single clusterfile.",
     12),
    ("10-demo-operators-render",
     "Same clusterfile, different template. "
     "Operator subscriptions, operator groups, namespaces. "
     "Day-2 operator manifests ready to apply.",
     10),
    ("11-demo-siteconfig",
     "For ACM SiteConfig, a ClusterInstance custom resource from the same file. "
     "Every host, every network interface, every BMC credential. "
     "Fully populated, fully validated.",
     10),
    ("12-numbers",
     "187 fields in, 1,049 fields out. "
     "A 5.6 times expansion in structured data. "
     "267 input lines become 2,579 output lines across 11 templates. "
     "That's a 9.7 times line expansion.",
     15),
    ("13-time-cost",
     "First cluster: six hours manual, thirty minutes with Clusterfile. "
     "92 percent savings. "
     "A ten-cluster engagement saves forty-five hundred dollars in consulting time. "
     "Switching deployment methods takes one minute instead of four hours.",
     12),
    ("14-architecture",
     "11 platforms, 6 deployment methods, 6 operator plugins, 134 automated tests. "
     "From AWS to baremetal to KubeVirt. "
     "Agent-based, IPI, ACM ZTP, CAPI, UPI, and SiteConfig.",
     10),
    ("15-cta",
     "Try it now. One container, one command. "
     "Pull the image, open localhost eight-thousand, load a sample, "
     "and render your first output in under a minute.",
     8),
    ("16-end", "", 5),
]

# ---------------------------------------------------------------------------
# TTS audio generation
# ---------------------------------------------------------------------------
async def generate_audio():
    """Generate narration MP3 files using edge-tts."""
    import edge_tts

    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    voice = "en-US-AndrewNeural"
    print(f"Generating narration audio (voice: {voice})...")

    for slide_name, text, min_dur in NARRATION:
        out = AUDIO_DIR / f"{slide_name}.mp3"
        if not text.strip():
            # Silent clip — create a tiny silent MP3 placeholder
            _create_silent_mp3(str(out), min_dur)
            print(f"  {slide_name}: silence ({min_dur}s)")
            continue
        communicate = edge_tts.Communicate(text, voice, rate="-5%")
        await communicate.save(str(out))
        print(f"  {slide_name}: saved")

    print(f"Generated {len(NARRATION)} audio files in {AUDIO_DIR}")

def _create_silent_mp3(path, duration_secs):
    """Create a silent audio file using moviepy."""
    import numpy as np
    from moviepy import AudioClip
    silent = AudioClip(lambda t: np.zeros((1, 2)) if np.isscalar(t) else np.zeros((len(t), 2)),
                       duration=float(duration_secs), fps=44100)
    silent.write_audiofile(path, fps=44100, logger=None)

# ---------------------------------------------------------------------------
# Video assembly
# ---------------------------------------------------------------------------
def assemble_video():
    """Assemble slides + audio into final MP4."""
    from moviepy import ImageClip, AudioFileClip, CompositeAudioClip, concatenate_videoclips

    print("Assembling video...")
    clips = []

    for slide_name, text, min_dur in NARRATION:
        slide_path = SLIDES_DIR / f"{slide_name}.png"
        audio_path = AUDIO_DIR / f"{slide_name}.mp3"

        if not slide_path.exists():
            print(f"  [WARN] Missing slide: {slide_path}")
            continue

        # Determine duration from audio or minimum
        has_narration = bool(text.strip())
        audio = None
        if has_narration and audio_path.exists():
            audio = AudioFileClip(str(audio_path))
            duration = max(audio.duration + 1.0, min_dur)
        else:
            duration = min_dur

        # Create image clip
        clip = ImageClip(str(slide_path), duration=duration)

        # Attach audio (only for narrated slides)
        if audio is not None:
            clip = clip.with_audio(audio)

        clips.append(clip)
        print(f"  {slide_name}: {duration:.1f}s")

    if not clips:
        print("ERROR: No clips to assemble!")
        return

    # Concatenate with crossfade
    # moviepy 2.x: use concatenate with crossfade method
    final = concatenate_videoclips(clips, method="compose")

    print(f"Total duration: {final.duration:.1f}s ({final.duration/60:.1f}m)")
    print(f"Writing to {OUTPUT_FILE}...")

    final.write_videofile(
        str(OUTPUT_FILE),
        fps=24,
        codec="libx264",
        audio_codec="aac",
        preset="medium",
        threads=4,
        logger="bar",
    )
    print(f"Done: {OUTPUT_FILE} ({os.path.getsize(OUTPUT_FILE) / 1024 / 1024:.1f} MB)")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Clusterfile presentation video generator")
    parser.add_argument("--slides-only", action="store_true", help="Only generate slide PNGs")
    parser.add_argument("--audio-only", action="store_true", help="Only generate TTS audio")
    parser.add_argument("--assemble-only", action="store_true", help="Only assemble video from existing slides/audio")
    parser.add_argument("--skip-screenshots", action="store_true", help="Skip screenshot capture step")
    args = parser.parse_args()

    if args.slides_only:
        generate_slides()
        return
    if args.audio_only:
        asyncio.run(generate_audio())
        return
    if args.assemble_only:
        assemble_video()
        return

    # Full pipeline
    print("=" * 60)
    print("Clusterfile Presentation Video Generator")
    print("=" * 60)

    # Step 1: Generate slide images
    generate_slides()
    print()

    # Step 2: Generate TTS audio
    asyncio.run(generate_audio())
    print()

    # Step 3: Assemble video
    assemble_video()

if __name__ == "__main__":
    main()
