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
# Font helpers — minimum 40px for presentation legibility
# ---------------------------------------------------------------------------
_font_cache = {}

def _find_font():
    """Find a usable sans-serif font on the system."""
    candidates = [
        "/usr/share/fonts/redhat-vf/RedHatText[wght].ttf",
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
        "/usr/share/fonts/redhat-vf/RedHatText[wght].ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/google-noto/NotoSans-Bold.ttf",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return _find_font()

FONT_PATH = _find_font()
BOLD_FONT_PATH = _find_bold_font()
if not FONT_PATH:
    print("WARNING: No TrueType font found, using Pillow default (reduced quality)")

def font(size, bold=False):
    key = (size, bold)
    if key not in _font_cache:
        path = BOLD_FONT_PATH if bold else FONT_PATH
        if path:
            _font_cache[key] = ImageFont.truetype(path, size)
        else:
            _font_cache[key] = ImageFont.load_default(size=size)
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

def draw_footer(draw, text="quay.io/dds/clusterfile-editor:latest"):
    draw_centred(draw, H - 60, text, font(40), GREY)

# ---------------------------------------------------------------------------
# Slide generators — narrative: portability, version control, secrets,
#                    extensibility, installer/day-2 agnostic
# ---------------------------------------------------------------------------
def slide_title():
    """Slide 1: Title card."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 200, "Clusterfile", font(120, bold=True), WHITE)
    draw_centred(draw, 370, "Portable cluster definitions for OpenShift", font(56), (187, 222, 251))
    draw_centred(draw, 500, "One file  \u00b7  Any installer  \u00b7  Any platform", font(48), (144, 202, 249))
    draw_centred(draw, 680, "v3.7.1", font(56, bold=True), (200, 230, 255))
    return img

def slide_portability():
    """Slide 2: Portability — one file runs everywhere."""
    img, draw = new_slide()
    draw_centred(draw, 30, "Portable by Design", font(72, bold=True), BG_DARK)
    draw_centred(draw, 120, "One YAML file \u2192 any platform, any deployment method", font(52), GREY)

    # Platform groups as flowing text
    groups = [
        ("Public Cloud", "AWS  \u00b7  Azure  \u00b7  GCP  \u00b7  IBM Cloud", BLUE),
        ("On-Premises", "vSphere  \u00b7  Nutanix  \u00b7  OpenStack", ORANGE),
        ("Specialized", "Baremetal  \u00b7  KubeVirt  \u00b7  SNO  \u00b7  External", PURPLE),
    ]
    sy = 240
    for label, items, colour in groups:
        draw_left(draw, 120, sy, label, font(48, bold=True), colour)
        draw_left(draw, 580, sy, items, font(48), colour)
        sy += 80

    draw.line([(120, sy + 10), (W - 120, sy + 10)], fill=LIGHT_GREY, width=2)

    # Deployment methods
    sy += 40
    draw_left(draw, 120, sy, "Deployment:", font(48, bold=True), BG_DARK)
    draw_left(draw, 530, sy, "Agent  \u00b7  IPI  \u00b7  ZTP  \u00b7  CAPI  \u00b7  UPI  \u00b7  SiteConfig", font(48), BG_DARK)

    # Key message
    draw_centred(draw, 720, "Switch deployment method in one minute", font(56, bold=True), GREEN)
    draw_centred(draw, 810, "not four hours", font(48), GREEN)
    draw_footer(draw)
    return img

def slide_version_control():
    """Slide 3: Version control friendly."""
    img, draw = new_slide()
    draw_centred(draw, 30, "Version-Control Friendly", font(72, bold=True), BG_DARK)
    draw_centred(draw, 120, "Compact, readable, safe to commit", font(52), GREY)

    # Three key properties as big cards
    props = [
        ("Human-readable YAML", "267 lines define an\nentire cluster", BLUE),
        ("No embedded secrets", "File paths, not\nbase64 blobs", PURPLE),
        ("Clean git diffs", "Every change is\nvisible and reviewable", GREEN),
    ]
    card_w, card_h = 520, 280
    gap = 40
    total = len(props) * card_w + (len(props) - 1) * gap
    sx = (W - total) // 2
    for i, (title, detail, colour) in enumerate(props):
        x = sx + i * (card_w + gap)
        y = 260
        draw_card(draw, x, y, card_w, card_h, WHITE, colour)
        draw_centred(draw, y + 30, title, font(44, bold=True), colour)
        for k, line in enumerate(detail.split("\n")):
            draw_centred(draw, y + 120 + k * 55, line, font(44), BLACK)

    # Bottom message
    draw_centred(draw, 640, "267 input lines \u2192 2,579 output lines", font(56, bold=True), BG_DARK)
    draw_centred(draw, 730, "9.7x expansion, fully version-controlled", font(48), BLUE)
    draw_footer(draw)
    return img

def slide_extensibility():
    """Slide 4: Extensible plugin architecture."""
    img, draw = new_slide()
    draw_centred(draw, 30, "Extensible Plugin Architecture", font(72, bold=True), BG_DARK)
    draw_centred(draw, 120, "Add an operator \u2192 get schema validation + templates", font(48), GREY)

    # Central clusterfile box
    cx, cy, cw, ch = 510, 240, 900, 160
    draw_card(draw, cx, cy, cw, ch, BG_DARK, BG_DARK)
    draw_centred(draw, cy + 15, "clusterfile.yaml", font(56, bold=True), WHITE)
    draw_centred(draw, cy + 85, "cluster  \u00b7  network  \u00b7  hosts  \u00b7  plugins", font(44), (187, 222, 251))

    # Plugin cards
    plugins = [
        ("ArgoCD", BLUE),
        ("LVM Storage", ORANGE),
        ("cert-manager", PURPLE),
        ("external-secrets", GREEN),
    ]
    card_w = 380
    gap = 30
    total = len(plugins) * card_w + (len(plugins) - 1) * gap
    sx = (W - total) // 2
    for i, (name, colour) in enumerate(plugins):
        x = sx + i * (card_w + gap)
        y = 480
        draw.line([(W // 2, cy + ch), (x + card_w // 2, y)], fill=colour, width=2)
        draw_card(draw, x, y, card_w, 90, WHITE, colour)
        draw_centred(draw, y + 18, name, font(44, bold=True), colour)

    # Installer agnostic message
    draw_centred(draw, 650, "Day-1: installer agnostic", font(56, bold=True), BG_DARK)
    draw_centred(draw, 730, "IPI  \u00b7  Agent-based  \u00b7  ACM ZTP  \u00b7  SiteConfig  \u00b7  CAPI", font(44), BG_DARK)

    draw_centred(draw, 840, "Day-2: operator lifecycle from the same source of truth", font(48), ORANGE)
    draw_footer(draw)
    return img

def slide_secrets():
    """Slide 5: Externalized secrets."""
    img, draw = new_slide()
    draw_centred(draw, 30, "Externalized Secrets", font(72, bold=True), BG_DARK)
    draw_centred(draw, 120, "File paths, not inline blobs", font(52), GREY)

    # File path examples (4 with bigger fonts)
    refs = [
        ("pullSecret:", "~/pull-secret.json", PURPLE),
        ("sshKeys:", "~/.ssh/id_ed25519.pub", PURPLE),
        ("trustBundle:", "~/ca-bundle.pem", PURPLE),
        ("bmc.password:", "~/bmc.pass", PURPLE),
    ]
    y = 250
    for field, path, colour in refs:
        draw_left(draw, 200, y, field, font(48, bold=True), colour)
        draw_left(draw, 680, y, path, font(48), BLUE)
        y += 80

    draw.line([(200, y + 15), (W - 200, y + 15)], fill=LIGHT_GREY, width=2)

    # Key messages
    draw_centred(draw, y + 60, "Loaded at render time \u2014 never stored in the clusterfile", font(48, bold=True), BG_DARK)
    draw_centred(draw, y + 140, "Safe to commit  \u00b7  Safe to share  \u00b7  Safe to version", font(48), GREEN)

    # Day-2 box
    draw_card(draw, 200, y + 230, W - 400, 120, (243, 229, 245), PURPLE)
    draw_centred(draw, y + 260, "Day-2: Vault / OpenBao \u2192 External Secrets Operator \u2192 K8s Secrets", font(44, bold=True), PURPLE)

    draw_footer(draw)
    return img

def slide_numbers():
    """Slide 13: The numbers — expansion ratios."""
    img, draw = new_slide()
    draw_centred(draw, 30, "The Portability Dividend", font(72, bold=True), BG_DARK)
    draw_centred(draw, 120, "One clusterfile, massive output", font(52), GREY)

    # Three big ratio cards
    ratios = [
        ("9.7x", "Line expansion", BLUE, CARD_BG),
        ("5.6x", "Field expansion", ORANGE, (255, 243, 224)),
        ("56", "K8s resources", PURPLE, (243, 229, 245)),
    ]
    card_w, card_h = 520, 320
    gap = 50
    total = len(ratios) * card_w + (len(ratios) - 1) * gap
    sx = (W - total) // 2
    for i, (big, label, colour, bg) in enumerate(ratios):
        x = sx + i * (card_w + gap)
        y = 240
        draw_card(draw, x, y, card_w, card_h, bg, colour)
        draw_centred(draw, y + 30, big, font(96, bold=True), colour)
        draw_centred(draw, y + 170, label, font(48, bold=True), BLACK)

    # Bottom summary
    draw_centred(draw, 650, "267 lines in  \u2192  2,579 lines out across 11 templates", font(48, bold=True), BG_DARK)
    draw_centred(draw, 740, "187 fields in  \u2192  1,049 fields out", font(48), BLUE)
    draw_footer(draw)
    return img

def slide_time_cost():
    """Slide 14: Time & cost comparison."""
    img, draw = new_slide()
    draw_centred(draw, 30, "Time & Cost Savings", font(72, bold=True), BG_DARK)
    draw_centred(draw, 120, "$150/hr consultant rate, baremetal 3-node cluster", font(48), GREY)

    # Three stat boxes — big and clear
    stats = [
        ("92%", "time savings", "First cluster:\n6h \u2192 30 min", BLUE),
        ("1 min", "to switch method", "Not 4 hours\nof rework", GREEN),
        ("$4,500", "saved per 10 clusters", "33h \u2192 3h\nof config work", ORANGE),
    ]
    card_w, card_h = 520, 440
    gap = 50
    total = len(stats) * card_w + (len(stats) - 1) * gap
    sx = (W - total) // 2
    for i, (big, label, detail, colour) in enumerate(stats):
        x = sx + i * (card_w + gap)
        y = 240
        draw_card(draw, x, y, card_w, card_h, WHITE, colour)
        draw_centred(draw, y + 30, big, font(88, bold=True), colour)
        draw_centred(draw, y + 150, label, font(44, bold=True), BLACK)
        for k, line in enumerate(detail.split("\n")):
            draw_centred(draw, y + 260 + k * 55, line, font(44), GREY)

    draw_centred(draw, 760, "Portability saves real time and money", font(52, bold=True), GREEN)
    draw_footer(draw)
    return img

def slide_platform_coverage():
    """Slide 15: Platform coverage summary."""
    img, draw = new_slide()
    draw_centred(draw, 30, "Platform Coverage", font(72, bold=True), BG_DARK)

    # Four big stat cards
    coverage = [
        ("11", "Platforms", BLUE),
        ("6", "Deployment\nMethods", ORANGE),
        ("6", "Operator\nPlugins", PURPLE),
        ("134", "Automated\nTests", GREEN),
    ]
    card_w, card_h = 380, 350
    gap = 40
    total = len(coverage) * card_w + (len(coverage) - 1) * gap
    sx = (W - total) // 2
    for i, (num, label, colour) in enumerate(coverage):
        x = sx + i * (card_w + gap)
        y = 200
        draw_card(draw, x, y, card_w, card_h, WHITE, colour)
        draw_centred(draw, y + 30, num, font(96, bold=True), colour)
        for k, line in enumerate(label.split("\n")):
            draw_centred(draw, y + 175 + k * 55, line, font(44, bold=True), BLACK)

    # Bottom: key message
    draw_centred(draw, 650, "From AWS to baremetal to KubeVirt", font(52, bold=True), BG_DARK)
    draw_centred(draw, 730, "Agent-based  \u00b7  IPI  \u00b7  ACM ZTP  \u00b7  CAPI  \u00b7  UPI  \u00b7  SiteConfig", font(44), BG_DARK)
    draw_centred(draw, 830, "Every platform \u00d7 method \u00d7 plugin combination tested", font(44), GREEN)
    draw_footer(draw)
    return img

def slide_cli_demo():
    """Slide 12: CLI demo — terminal-style display."""
    img, draw = new_slide((30, 30, 30))
    draw_centred(draw, 25, "CLI: Same Templates, No Browser", font(72, bold=True), WHITE)
    draw_centred(draw, 115, "Perfect for CI/CD pipelines and GitOps", font(48), (144, 202, 249))

    # Terminal window frame
    term_x, term_y, term_w, term_h = 80, 200, W - 160, 800
    draw_card(draw, term_x, term_y, term_w, term_h, (20, 20, 20), (80, 80, 80), radius=12)
    draw.rectangle([(term_x, term_y), (term_x + term_w, term_y + 50)], fill=(50, 50, 50))
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        draw.ellipse([term_x + 18 + i * 30, term_y + 14, term_x + 36 + i * 30, term_y + 32], fill=c)
    draw_left(draw, term_x + 120, term_y + 10, "bash \u2014 clusterfile", font(40), (160, 160, 160))

    ty = term_y + 75
    green = (100, 255, 100)
    white = (220, 220, 220)
    grey = (120, 120, 120)
    cyan = (100, 200, 255)

    # Command
    draw_left(draw, term_x + 30, ty, "$ python process.py \\", font(40, bold=True), green)
    ty += 55
    draw_left(draw, term_x + 80, ty, "-t templates/install-config.yaml.tpl \\", font(40), white)
    ty += 55
    draw_left(draw, term_x + 80, ty, "-d data/baremetal.clusterfile", font(40), white)
    ty += 70

    # Output
    draw_left(draw, term_x + 30, ty, "# Rendered install-config.yaml", font(40), grey)
    ty += 55
    lines = [
        ("apiVersion:", " v1", ORANGE, cyan),
        ("baseDomain:", " example.com", ORANGE, cyan),
        ("networking:", "", ORANGE, white),
        ("  networkType:", " OVNKubernetes", ORANGE, cyan),
        ("platform:", "", ORANGE, white),
        ("  baremetal:", "", ORANGE, white),
        ("    hosts:", " [... 3 hosts with BMC ...]", ORANGE, grey),
    ]
    for key, val, kc, vc in lines:
        draw_left(draw, term_x + 30, ty, key, font(40), kc)
        bbox = draw.textbbox((0, 0), key, font=font(40))
        kw = bbox[2] - bbox[0]
        draw_left(draw, term_x + 30 + kw, ty, val, font(40), vc)
        ty += 50

    # Second command
    ty += 20
    draw_left(draw, term_x + 30, ty, "$ python process.py -t acm-ztp.yaml.tpl ... | wc -l", font(40, bold=True), green)
    ty += 55
    draw_left(draw, term_x + 30, ty, "648", font(48, bold=True), (255, 200, 100))

    return img

def slide_cta():
    """Slide 16: Call to action."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 80, "Try It Now", font(96, bold=True), WHITE)
    draw_centred(draw, 210, "One container, one command", font(56), (187, 222, 251))

    # Container command card
    draw_card(draw, 150, 330, W - 300, 120, (30, 30, 30), (100, 100, 100))
    draw_centred(draw, 355, "podman run -d -p 8000:8000 quay.io/dds/clusterfile-editor", font(42), (100, 255, 100))

    # Steps
    steps = [
        "1.  Open localhost:8000 and load a sample clusterfile",
        "2.  Switch platforms, enable plugins, render outputs",
        "3.  Use the CLI in your pipeline",
    ]
    sy = 530
    for step in steps:
        draw_centred(draw, sy, step, font(44), (200, 230, 255))
        sy += 75

    draw_centred(draw, 860, "Portable  \u00b7  Version-controlled  \u00b7  Extensible", font(48, bold=True), (144, 202, 249))
    return img

def slide_end():
    """Slide 17: End card."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 250, "Clusterfile", font(96, bold=True), WHITE)
    draw_centred(draw, 390, "v3.7.1", font(56), (187, 222, 251))
    draw_centred(draw, 500, "One file  \u00b7  Any installer  \u00b7  Any platform", font(48), (144, 202, 249))
    draw_centred(draw, 640, "Portable  \u00b7  Version-controlled  \u00b7  Extensible", font(44), GREY)
    return img

# ---------------------------------------------------------------------------
# SVG \u2192 PNG conversion
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
# Screenshot \u2192 slide
# ---------------------------------------------------------------------------
def screenshot_to_slide(screenshot_path, output_path):
    """Wrap a screenshot in a 1920x1080 frame."""
    if not os.path.exists(screenshot_path):
        print(f"  [WARN] Screenshot not found: {screenshot_path}, generating placeholder")
        img, draw = new_slide()
        draw_centred(draw, H // 2 - 40, f"[Screenshot: {Path(screenshot_path).stem}]", font(56, bold=True), GREY)
        draw_centred(draw, H // 2 + 40, "Live editor screenshot", font(44), GREY)
        img.save(str(output_path))
        return str(output_path)

    shot = Image.open(screenshot_path).convert("RGB")
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

    # 2. Portability
    slide_portability().save(str(SLIDES_DIR / "02-portability.png"))
    slides.append("02-portability.png")
    print("  02-portability")

    # 3. Version control
    slide_version_control().save(str(SLIDES_DIR / "03-version-control.png"))
    slides.append("03-version-control.png")
    print("  03-version-control")

    # 4. Extensibility
    slide_extensibility().save(str(SLIDES_DIR / "04-extensibility.png"))
    slides.append("04-extensibility.png")
    print("  04-extensibility")

    # 5. Externalized secrets
    slide_secrets().save(str(SLIDES_DIR / "05-secrets.png"))
    slides.append("05-secrets.png")
    print("  05-secrets")

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

    # 12. CLI demo
    slide_cli_demo().save(str(SLIDES_DIR / "12-demo-cli.png"))
    slides.append("12-demo-cli.png")
    print("  12-demo-cli")

    # 13. Numbers
    slide_numbers().save(str(SLIDES_DIR / "13-numbers.png"))
    slides.append("13-numbers.png")
    print("  13-numbers")

    # 14. Time & cost
    slide_time_cost().save(str(SLIDES_DIR / "14-time-cost.png"))
    slides.append("14-time-cost.png")
    print("  14-time-cost")

    # 15. Platform coverage
    arch_svg = COLLATERAL / "architecture.svg"
    rendered = None
    if arch_svg.exists() and HAS_CAIROSVG:
        rendered = svg_to_slide(arch_svg, SLIDES_DIR / "15-architecture.png")
    if not rendered:
        slide_platform_coverage().save(str(SLIDES_DIR / "15-architecture.png"))
    slides.append("15-architecture.png")
    print("  15-architecture")

    # 16. CTA
    slide_cta().save(str(SLIDES_DIR / "16-cta.png"))
    slides.append("16-cta.png")
    print("  16-cta")

    # 17. End card
    slide_end().save(str(SLIDES_DIR / "17-end.png"))
    slides.append("17-end.png")
    print("  17-end")

    print(f"Generated {len(slides)} slides in {SLIDES_DIR}")
    return slides

# ---------------------------------------------------------------------------
# Narration — focused on: portability, version control, externalized secrets,
#             extensibility with plugins, installer/day-2 agnostic
# ---------------------------------------------------------------------------
NARRATION = [
    ("01-title", "", 5),
    ("02-portability",
     "One clusterfile runs on eleven platforms and six deployment methods. "
     "AWS, Azure, vSphere, baremetal, Kube-Virt \u2014 same YAML, different output. "
     "Switch from agent-based to ACM ZTP in one minute, not four hours. "
     "That's portability by design.",
     15),
    ("03-version-control",
     "The clusterfile is designed for version control. "
     "Two hundred sixty-seven lines of human-readable YAML. "
     "No embedded secrets, no base64 blobs. "
     "Every change shows up in a clean git diff. "
     "Compact enough to read, safe enough to commit.",
     12),
    ("04-extensibility",
     "Need an operator? Add a plugin. "
     "Each plugin brings its own schema validation and Jinja2 templates. "
     "ArgoCD, LVM Storage, cert-manager, external-secrets \u2014 all pluggable. "
     "The same architecture handles day-one installers and day-two operations. "
     "Installer agnostic. Operator agnostic. Fully extensible.",
     15),
    ("05-secrets",
     "Secrets stay on disk as file paths. "
     "Pull secrets, SSH keys, certificates, BMC credentials \u2014 "
     "the template processor reads and inlines them at render time. "
     "Your clusterfile stays compact and safe to commit. "
     "For day-two, External Secrets Operator handles the rest.",
     12),
    ("06-demo-baremetal",
     "Here's a baremetal cluster in the web editor. "
     "The form is generated from the JSON schema. "
     "One portable definition for the entire cluster.",
     12),
    ("07-demo-kubevirt",
     "Switch to Kube-Virt. The schema adapts instantly. "
     "BMC fields disappear, Kube-Virt options appear. "
     "One clusterfile, portable across platforms.",
     12),
    ("08-demo-operators",
     "Enable operators with a toggle. Each plugin extends the schema. "
     "Smart defaults fill in. "
     "Extensibility without complexity.",
     10),
    ("09-demo-install-config",
     "Render install-config. The same clusterfile produces output "
     "for any installer. Installer agnostic by design.",
     10),
    ("10-demo-operators-render",
     "Different template, same clusterfile. "
     "Operator subscriptions, namespaces, operator groups. "
     "Day-two operations from the same source of truth.",
     10),
    ("11-demo-siteconfig",
     "ACM SiteConfig from the same file. "
     "Every host, every interface, every credential. "
     "One definition, any deployment method.",
     10),
    ("12-demo-cli",
     "The same templates work from the command line. "
     "Run process dot py with a template and a clusterfile. "
     "No browser needed. "
     "Perfect for CI/CD pipelines and GitOps workflows.",
     10),
    ("13-numbers",
     "One clusterfile produces fifty-six Kubernetes resources. "
     "One hundred eighty-seven input fields become over a thousand output fields. "
     "That's a five-point-six times expansion. "
     "The portability dividend is real.",
     12),
    ("14-time-cost",
     "First cluster: six hours manual, thirty minutes with Clusterfile. "
     "92 percent savings. "
     "Switching deployment methods takes one minute. "
     "The portability dividend is real money saved.",
     12),
    ("15-architecture",
     "Eleven platforms, six deployment methods, six operator plugins, "
     "one hundred thirty-four automated tests. "
     "Portable, extensible, version-controlled.",
     10),
    ("16-cta",
     "Try it now. One container, one command. "
     "Open localhost eight-thousand, load a sample, "
     "and render your first output in under a minute.",
     8),
    ("17-end", "", 5),
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
# Cursor + click ripple for demo screenshots
# ---------------------------------------------------------------------------
DEMO_CLICK_POSITIONS = {
    "06-demo-baremetal": (155, 130),
    "07-demo-kubevirt": (155, 130),
    "08-demo-operators": (155, 265),
    "09-demo-install-config": (1330, 55),
    "10-demo-operators-render": (510, 290),
    "11-demo-siteconfig": (510, 290),
}

def create_cursor_image():
    """Draw a 40x40 white arrow cursor with black outline using Pillow."""
    img = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    outer = [(0, 0), (0, 32), (9, 24), (15, 37), (21, 34), (15, 21), (25, 21)]
    draw.polygon(outer, fill=(0, 0, 0, 255))
    inner = [(2, 4), (2, 27), (10, 21), (16, 33), (19, 31), (13, 19), (22, 19)]
    draw.polygon(inner, fill=(255, 255, 255, 255))
    return img

def add_click_indicator(clip, click_x, click_y):
    """Add animated cursor fade-in + click ripple overlay to an ImageClip."""
    import numpy as np
    from moviepy import VideoClip

    cursor_pil = create_cursor_image()
    cursor_arr = np.array(cursor_pil)
    base_frame = clip.get_frame(0).copy()
    duration = clip.duration

    def _overlay_cursor(frame, alpha_mult):
        ch, cw = cursor_arr.shape[:2]
        y1, y2 = max(0, click_y), min(frame.shape[0], click_y + ch)
        x1, x2 = max(0, click_x), min(frame.shape[1], click_x + cw)
        sy1, sy2 = y1 - click_y, y2 - click_y
        sx1, sx2 = x1 - click_x, x2 - click_x
        if y2 > y1 and x2 > x1:
            a = cursor_arr[sy1:sy2, sx1:sx2, 3:4].astype(np.float32) / 255.0 * alpha_mult
            rgb = cursor_arr[sy1:sy2, sx1:sx2, :3].astype(np.float32)
            bg = frame[y1:y2, x1:x2].astype(np.float32)
            frame[y1:y2, x1:x2] = (rgb * a + bg * (1.0 - a)).astype(np.uint8)
        return frame

    def _overlay_ripple(frame, ripple_t):
        radius = int(ripple_t * 60)
        ripple_alpha = 1.0 - ripple_t
        if radius <= 0 or ripple_alpha <= 0:
            return frame
        pad = radius + 4
        y1, y2 = max(0, click_y - pad), min(frame.shape[0], click_y + pad)
        x1, x2 = max(0, click_x - pad), min(frame.shape[1], click_x + pad)
        if y2 <= y1 or x2 <= x1:
            return frame
        crop = Image.fromarray(frame[y1:y2, x1:x2])
        overlay = Image.new("RGBA", crop.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(overlay)
        rcx, rcy = click_x - x1, click_y - y1
        d.ellipse(
            [rcx - radius, rcy - radius, rcx + radius, rcy + radius],
            outline=(255, 255, 255, int(200 * ripple_alpha)),
            width=3,
        )
        result = Image.alpha_composite(crop.convert("RGBA"), overlay)
        frame[y1:y2, x1:x2] = np.array(result.convert("RGB"))
        return frame

    static_frame = _overlay_cursor(base_frame.copy(), 1.0)

    def make_frame(t):
        if t >= 0.6:
            return static_frame
        frame = base_frame.copy()
        cursor_alpha = min(t / 0.3, 1.0)
        if cursor_alpha > 0:
            frame = _overlay_cursor(frame, cursor_alpha)
        if 0.3 <= t < 0.6:
            frame = _overlay_ripple(frame, (t - 0.3) / 0.3)
        return frame

    new_clip = VideoClip(make_frame, duration=duration)
    if clip.audio is not None:
        new_clip = new_clip.with_audio(clip.audio)
    return new_clip

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

        has_narration = bool(text.strip())
        audio = None
        if has_narration and audio_path.exists():
            audio = AudioFileClip(str(audio_path))
            duration = max(audio.duration + 1.0, min_dur)
        else:
            duration = min_dur

        clip = ImageClip(str(slide_path), duration=duration)

        if slide_name in DEMO_CLICK_POSITIONS:
            cx, cy = DEMO_CLICK_POSITIONS[slide_name]
            clip = add_click_indicator(clip, cx, cy)
            print(f"  {slide_name}: +cursor at ({cx},{cy})")

        if audio is not None:
            clip = clip.with_audio(audio)

        clips.append(clip)
        print(f"  {slide_name}: {duration:.1f}s")

    if not clips:
        print("ERROR: No clips to assemble!")
        return

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

    print("=" * 60)
    print("Clusterfile Presentation Video Generator")
    print("=" * 60)

    generate_slides()
    print()
    asyncio.run(generate_audio())
    print()
    assemble_video()

if __name__ == "__main__":
    main()
