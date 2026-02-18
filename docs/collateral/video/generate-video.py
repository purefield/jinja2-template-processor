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

def draw_footer(draw, text="Clusterfile v3.6.0 — quay.io/dds/clusterfile-editor:latest"):
    draw_centred(draw, H - 55, text, font(28), GREY)

# ---------------------------------------------------------------------------
# Slide generators
# ---------------------------------------------------------------------------
def slide_title():
    """Slide 1: Title card."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 260, "Clusterfile", font(108, bold=True), WHITE)
    draw_centred(draw, 400, "One definition, every deployment method", font(48), (187, 222, 251))
    draw_centred(draw, 490, "A declarative cluster intent format + template processor + web editor", font(34), (144, 202, 249))
    draw_centred(draw, 550, "for OpenShift", font(34), (144, 202, 249))
    draw_centred(draw, 680, "v3.6.0", font(38, bold=True), (200, 230, 255))
    return img

def slide_problem():
    """Slide 2: The problem — config sprawl."""
    img, draw = new_slide()
    draw_centred(draw, 50, "The Problem: Configuration Sprawl", font(60, bold=True), BG_DARK)
    draw_centred(draw, 135, "One cluster, five files, five formats", font(38), GREY)

    # Draw file boxes (3 combined)
    files = [
        ("install + agent-config", "IPI / ABI / Agent", BLUE),
        ("ACM ZTP / SiteConfig", "Fleet management", RED),
        ("operators.yaml", "6 subscriptions", PURPLE),
    ]
    box_w, box_h, gap = 480, 160, 50
    total_w = len(files) * box_w + (len(files) - 1) * gap
    start_x = (W - total_w) // 2
    for i, (name, desc, colour) in enumerate(files):
        x = start_x + i * (box_w + gap)
        y = 230
        draw_card(draw, x, y, box_w, box_h, WHITE, colour)
        draw_centred(draw, y + 30, name, font(32, bold=True), colour)
        draw_centred(draw, y + 85, desc, font(28), GREY)

    # Pain points (3 shorter)
    pains = [
        "Each file has its own format, assumptions, and gotchas",
        "A single network change touches 3+ files",
        "No cross-file validation — mismatches cause silent failures",
    ]
    for i, pain in enumerate(pains):
        bbox = draw.textbbox((0, 0), pain, font=font(32))
        tw = bbox[2] - bbox[0]
        draw_left(draw, max(120, (W - tw) // 2), 470 + i * 65, f"\u2022  {pain}", font(32), BLACK)

    draw_centred(draw, 700, "Result: Fragile installs, slow onboarding, tribal knowledge", font(36, bold=True), RED)
    draw_centred(draw, 770, "\"We spent 4 hours debugging a network mismatch\"", font(30), GREY)
    draw_footer(draw)
    return img

def slide_insight():
    """Slide 3: The insight — same data, different formats."""
    img, draw = new_slide()
    draw_centred(draw, 50, "The Insight", font(60, bold=True), BG_DARK)
    draw_centred(draw, 135, "Same data, different formats", font(38), GREY)

    # Table header (wider spacing for bigger font)
    cols = ["Data", "install-config", "ACM ZTP", "SiteConfig", "operators"]
    col_x = [100, 360, 680, 920, 1180]
    y_start = 250
    row_h = 70
    for i, col in enumerate(cols):
        draw_left(draw, col_x[i], y_start, col, font(32, bold=True), BG_DARK)
    draw.line([(80, y_start + 42), (1450, y_start + 42)], fill=LIGHT_GREY, width=2)

    rows = [
        ("Cluster name", True, True, True, True),
        ("Network config", True, True, True, False),
        ("Host BMC creds", False, True, True, False),
        ("Platform details", True, True, True, False),
        ("Operator config", False, False, False, True),
    ]
    for j, (label, *checks) in enumerate(rows):
        y = y_start + 55 + j * row_h
        draw_left(draw, col_x[0], y, label, font(32), BLACK)
        for k, v in enumerate(checks):
            marker = "Yes" if v else "\u2014"
            color = GREEN if v else LIGHT_GREY
            draw_left(draw, col_x[k + 1] + 30, y, marker, font(32, bold=True), color)

    draw_centred(draw, 680, "The cluster intent is constant.", font(40, bold=True), BG_DARK)
    draw_centred(draw, 740, "Only the output format changes.", font(40), BLUE)
    draw_footer(draw)
    return img

def slide_solution():
    """Slide 4: The solution — one file, many outputs."""
    img, draw = new_slide()
    draw_centred(draw, 50, "The Solution", font(60, bold=True), BG_DARK)
    draw_centred(draw, 135, "One YAML file, 102 templates, any output format", font(38), GREY)

    # Central clusterfile box
    cx, cy, cw, ch = 560, 280, 800, 210
    draw_card(draw, cx, cy, cw, ch, BG_DARK, BG_DARK)
    draw_centred(draw, cy + 25, "clusterfile.yaml", font(48, bold=True), WHITE)
    draw_centred(draw, cy + 90, "cluster | network | hosts | plugins", font(32), (187, 222, 251))
    draw_centred(draw, cy + 140, "Schema-validated  \u2022  File references for secrets", font(30), (144, 202, 249))

    # Output arrows (4 bigger boxes)
    outputs = [
        ("install-config.yaml", "(IPI / ABI)", BLUE),
        ("ACM ZTP manifests", "(5 CRs, 32 resources)", RED),
        ("SiteConfig CR", "(ClusterInstance)", ORANGE),
        ("operators.yaml", "(6 subscriptions)", PURPLE),
    ]
    start_y = 580
    box_w = 380
    gap = 40
    total_w = len(outputs) * box_w + (len(outputs) - 1) * gap
    sx = (W - total_w) // 2
    for i, (name, detail, colour) in enumerate(outputs):
        x = sx + i * (box_w + gap)
        y = start_y
        draw.line([(W // 2, cy + ch), (x + box_w // 2, y)], fill=colour, width=2)
        draw_card(draw, x, y, box_w, 100, WHITE, colour)
        draw_left(draw, x + 20, y + 12, name, font(28, bold=True), colour)
        draw_left(draw, x + 20, y + 52, detail, font(28), GREY)

    draw_centred(draw, 730, "Define once  \u2192  Render many  \u2192  Validate always", font(36, bold=True), GREEN)
    draw_footer(draw)
    return img

def slide_file_externalization():
    """Slide 5: File externalization."""
    img, draw = new_slide()
    draw_centred(draw, 50, "File Externalization", font(60, bold=True), BG_DARK)
    draw_centred(draw, 135, "Secrets and large content are file paths, not inline blobs", font(38), GREY)

    # File path examples
    refs = [
        ("pullSecret:", "~/pull-secret.json", "3 KB JSON auth blob"),
        ("sshKeys:", "~/.ssh/id_ed25519.pub", "SSH public key"),
        ("trustBundle:", "~/ca-bundle.pem", "4 KB certificate chain"),
        ("bmc.password:", "~/bmc.pass", "BMC credentials"),
        ("credentials:", "~/cloud-creds.json", "Cloud provider auth"),
    ]
    y = 240
    for field, path, desc in refs:
        draw_left(draw, 180, y, field, font(36, bold=True), PURPLE)
        draw_left(draw, 560, y, path, font(36), BLUE)
        draw_left(draw, 1080, y, f"\u2192  {desc}", font(32), GREY)
        y += 75

    # Separator
    draw.line([(180, y + 10), (W - 180, y + 10)], fill=LIGHT_GREY, width=2)

    # Explanation
    draw_centred(draw, y + 50, "load_file() reads content at render time", font(36, bold=True), BG_DARK)
    draw_centred(draw, y + 105, "Clusterfile stays compact, readable, and safe to commit", font(34), GREY)

    # Day-2 box
    draw_card(draw, 280, y + 175, W - 560, 130, (243, 229, 245), PURPLE)
    draw_centred(draw, y + 200, "Day-2: Vault / OpenBao  \u2192  External Secrets Operator  \u2192  K8s Secrets", font(34, bold=True), PURPLE)
    draw_centred(draw, y + 250, "Templates generate ESO manifests; ESO runs on the created cluster", font(30), GREY)

    draw_footer(draw)
    return img

def slide_numbers():
    """Slide 12: The numbers — expansion ratios."""
    img, draw = new_slide()
    draw_centred(draw, 50, "The Numbers", font(60, bold=True), BG_DARK)
    draw_centred(draw, 135, "Real data from production clusterfiles", font(38), GREY)

    # Three big ratio cards (enlarged)
    ratios = [
        ("9.7x", "Lines of code", "267 \u2192 2,579 output lines", BLUE, CARD_BG),
        ("5.6x", "Data fields", "187 \u2192 1,049 output fields", ORANGE, (255, 243, 224)),
        ("56", "K8s resources (ZTP)", "17 top-level + 39 nested", PURPLE, (243, 229, 245)),
    ]
    card_w, card_h = 520, 280
    gap = 50
    total = len(ratios) * card_w + (len(ratios) - 1) * gap
    sx = (W - total) // 2
    for i, (big, label, detail, colour, bg) in enumerate(ratios):
        x = sx + i * (card_w + gap)
        y = 230
        draw_card(draw, x, y, card_w, card_h, bg, colour)
        draw_centred(draw, y + 25, big, font(80, bold=True), colour)
        draw_centred(draw, y + 130, label, font(36, bold=True), BLACK)
        draw_centred(draw, y + 185, detail, font(32), GREY)

    # Bar chart (3 bars)
    bars = [
        ("ACM ZTP", 648, RED),
        ("agent-config", 245, BLUE),
        ("SiteConfig", 151, ORANGE),
    ]
    bar_y = 600
    max_w = 900
    max_val = 648
    draw_centred(draw, bar_y - 35, "Output fields per template (baremetal 3-node HA)", font(34, bold=True), BLACK)
    for i, (name, val, colour) in enumerate(bars):
        y = bar_y + i * 70
        draw_left(draw, 200, y + 5, name, font(30), BLACK)
        bw = int(val / max_val * max_w)
        draw_bar(draw, 480, y, bw, 45, colour)
        draw_left(draw, 490 + bw, y + 5, str(val), font(30, bold=True), colour)

    draw_footer(draw)
    return img

def slide_time_cost():
    """Slide 13: Time & cost comparison."""
    img, draw = new_slide()
    draw_centred(draw, 45, "Time & Cost: Manual vs. Clusterfile", font(56, bold=True), BG_DARK)
    draw_centred(draw, 120, "Baremetal 3-node cluster, 2,579 lines of config, $150/hr rate", font(32), GREY)

    # Table
    headers = ["Scenario", "Manual", "Clusterfile", "Savings"]
    hx = [160, 500, 820, 1170]
    hy = 200
    for i, h in enumerate(headers):
        draw_left(draw, hx[i], hy, h, font(34, bold=True), BG_DARK)
    draw.line([(140, hy + 45), (1520, hy + 45)], fill=LIGHT_GREY, width=2)

    rows = [
        ("First cluster", "6 hours / $900", "30 min / $75", "92% / $825"),
        ("Next cluster", "3 hours / $450", "15 min / $38", "92% / $412"),
        ("Switch method", "4 hours / $600", "1 min / $2.50", "99% / $598"),
        ("10 clusters", "33 hours / $4,950", "3 hours / $450", "91% / $4,500"),
    ]
    for j, (scenario, manual, cf, savings) in enumerate(rows):
        y = hy + 60 + j * 95
        bg = (250, 250, 250) if j % 2 == 0 else WHITE
        draw.rectangle([(140, y - 8), (1520, y + 58)], fill=bg)
        draw_left(draw, hx[0], y + 8, scenario, font(34, bold=True), BLACK)
        draw_left(draw, hx[1], y + 8, manual, font(34), RED)
        draw_left(draw, hx[2], y + 8, cf, font(34), GREEN)
        draw_left(draw, hx[3], y + 8, savings, font(34, bold=True), BLUE)

    draw.line([(140, hy + 60 + len(rows) * 95), (1520, hy + 60 + len(rows) * 95)], fill=LIGHT_GREY, width=2)
    draw_centred(draw, 660, "Time freed goes to architecture, migration, and higher-value work", font(34, bold=True), GREEN)

    # Bottom stat boxes
    stats = [
        ("92%", "savings on\nfirst cluster"),
        ("$4,500", "saved on a\n10-cluster engagement"),
        ("1 min", "to switch\ndeployment method"),
    ]
    box_w = 400
    gap = 50
    sx = (W - (3 * box_w + 2 * gap)) // 2
    for i, (big, detail) in enumerate(stats):
        x = sx + i * (box_w + gap)
        y = 730
        draw_card(draw, x, y, box_w, 190, CARD_BG, BLUE)
        draw_centred(draw, y + 20, big, font(64, bold=True), BLUE)
        for k, line in enumerate(detail.split("\n")):
            draw_centred(draw, y + 105 + k * 35, line, font(32), GREY)

    draw_footer(draw)
    return img

def slide_platform_coverage():
    """Slide 14: Platform coverage."""
    img, draw = new_slide()
    draw_centred(draw, 50, "Platform Coverage", font(60, bold=True), BG_DARK)
    draw_centred(draw, 135, "11 platforms, 6 deployment methods, 134 tests", font(38), GREY)

    # Platform grid (larger chips)
    platforms = [
        ("Public Cloud", ["AWS", "Azure", "GCP", "IBM Cloud"], BLUE),
        ("On-Premises", ["vSphere", "Nutanix", "OpenStack"], ORANGE),
        ("Specialized", ["Baremetal", "KubeVirt", "SNO", "External"], PURPLE),
    ]
    sy = 230
    for group, items, colour in platforms:
        draw_left(draw, 140, sy, group, font(38, bold=True), colour)
        for i, item in enumerate(items):
            x = 480 + i * 270
            draw_card(draw, x, sy - 10, 240, 60, WHITE, colour)
            draw_left(draw, x + 20, sy + 2, item, font(32), colour)
        sy += 110

    # Deployment methods
    draw.line([(140, sy + 10), (W - 140, sy + 10)], fill=LIGHT_GREY, width=2)
    sy += 45
    draw_left(draw, 140, sy, "Deployment methods:", font(38, bold=True), BG_DARK)
    methods = ["Agent-based", "IPI", "ACM ZTP", "ACM CAPI", "UPI", "SiteConfig"]
    for i, m in enumerate(methods):
        x = 140 + i * 270
        draw_card(draw, x, sy + 55, 250, 55, CARD_BG, BLUE)
        draw_left(draw, x + 18, sy + 65, m, font(30), BLUE)

    # Operator plugins
    sy += 165
    draw_left(draw, 140, sy, "Operator plugins:", font(38, bold=True), BG_DARK)
    operators = ["ArgoCD", "LVM Storage", "ODF", "ACM", "cert-manager", "external-secrets"]
    for i, op in enumerate(operators):
        x = 140 + i * 270
        draw_card(draw, x, sy + 55, 250, 55, (255, 243, 224), ORANGE)
        draw_left(draw, x + 18, sy + 65, op, font(30), ORANGE)

    # Test coverage
    sy += 165
    draw_centred(draw, sy, "134 automated tests \u2014 every platform \u00d7 method \u00d7 operator", font(34, bold=True), GREEN)

    draw_footer(draw)
    return img

def slide_cli_demo():
    """Slide 12: CLI demo — terminal-style display."""
    img, draw = new_slide((30, 30, 30))
    draw_centred(draw, 40, "CLI: Templates from the Terminal", font(60, bold=True), WHITE)
    draw_centred(draw, 120, "Same templates, no browser needed \u2014 perfect for CI/CD", font(38), (144, 202, 249))

    # Terminal window frame
    term_x, term_y, term_w, term_h = 100, 200, W - 200, 780
    draw_card(draw, term_x, term_y, term_w, term_h, (20, 20, 20), (80, 80, 80), radius=12)
    # Title bar
    draw.rectangle([(term_x, term_y), (term_x + term_w, term_y + 40)], fill=(50, 50, 50))
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        draw.ellipse([term_x + 15 + i * 25, term_y + 12, term_x + 29 + i * 25, term_y + 26], fill=c)
    draw_left(draw, term_x + 100, term_y + 8, "bash \u2014 clusterfile", font(28), (160, 160, 160))

    # Terminal content
    ty = term_y + 60
    green = (100, 255, 100)
    white = (220, 220, 220)
    grey = (120, 120, 120)
    cyan = (100, 200, 255)

    # Command prompt
    draw_left(draw, term_x + 30, ty, "$ ", font(30, bold=True), green)
    draw_left(draw, term_x + 60, ty, "python process.py \\", font(30), white)
    ty += 45
    draw_left(draw, term_x + 90, ty, "-t templates/install-config.yaml.tpl \\", font(30), white)
    ty += 45
    draw_left(draw, term_x + 90, ty, "-d data/baremetal.clusterfile", font(30), white)
    ty += 55

    # Output header
    draw_left(draw, term_x + 30, ty, "# Rendered install-config.yaml (106 fields)", font(28), grey)
    ty += 45

    # Sample YAML output
    lines = [
        ("apiVersion:", " v1", ORANGE, cyan),
        ("metadata:", "", ORANGE, white),
        ("  name:", " my-cluster", ORANGE, cyan),
        ("baseDomain:", " example.com", ORANGE, cyan),
        ("networking:", "", ORANGE, white),
        ("  networkType:", " OVNKubernetes", ORANGE, cyan),
        ("  machineNetwork:", "", ORANGE, white),
        ("    - cidr:", " 10.0.0.0/16", ORANGE, cyan),
        ("platform:", "", ORANGE, white),
        ("  baremetal:", "", ORANGE, white),
        ("    hosts:", " [... 3 hosts with BMC ...]", ORANGE, grey),
    ]
    for key, val, kc, vc in lines:
        draw_left(draw, term_x + 30, ty, key, font(28), kc)
        bbox = draw.textbbox((0, 0), key, font=font(28))
        kw = bbox[2] - bbox[0]
        draw_left(draw, term_x + 30 + kw, ty, val, font(28), vc)
        ty += 38

    # Second command
    ty += 20
    draw_left(draw, term_x + 30, ty, "$ ", font(30, bold=True), green)
    draw_left(draw, term_x + 60, ty, "python process.py -t acm-ztp.yaml.tpl -d data/baremetal.clusterfile | wc -l", font(28), white)
    ty += 45
    draw_left(draw, term_x + 30, ty, "648", font(30, bold=True), (255, 200, 100))

    return img

def slide_cta():
    """Slide 16: Call to action."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 100, "Try It Now", font(72, bold=True), WHITE)
    draw_centred(draw, 200, "One container, one command", font(42), (187, 222, 251))

    # Container command card
    draw_card(draw, 250, 300, W - 500, 100, (30, 30, 30), (100, 100, 100))
    draw_centred(draw, 325, "podman run -d -p 8000:8000 quay.io/dds/clusterfile-editor:v3.6.0", font(34), (100, 255, 100))

    # CLI command card
    draw_card(draw, 250, 440, W - 500, 100, (30, 30, 30), (100, 100, 100))
    draw_centred(draw, 465, "python process.py -t install-config.yaml.tpl -d data/baremetal.clusterfile", font(30), (100, 255, 100))

    # Steps (3 instead of 4)
    steps = [
        "1.  Pull the container and open localhost:8000",
        "2.  Load a sample clusterfile \u2014 try baremetal or kubevirt",
        "3.  Render outputs and use the CLI in your pipeline",
    ]
    sy = 610
    for step in steps:
        draw_centred(draw, sy, step, font(34), (200, 230, 255))
        sy += 60

    draw_centred(draw, 880, "quay.io/dds/clusterfile-editor:latest", font(32), GREY)
    return img

def slide_end():
    """Slide 16: End card."""
    img, draw = new_slide(BG_DARK)
    draw_centred(draw, 300, "Clusterfile", font(80, bold=True), WHITE)
    draw_centred(draw, 420, "v3.6.0", font(48), (187, 222, 251))
    draw_centred(draw, 520, "quay.io/dds/clusterfile-editor:latest", font(38), (144, 202, 249))
    draw_centred(draw, 620, "102 templates  |  11 platforms  |  6 operators  |  134 tests", font(34), GREY)
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
        draw_centred(draw, H // 2 - 30, f"[Screenshot: {Path(screenshot_path).stem}]", font(48, bold=True), GREY)
        draw_centred(draw, H // 2 + 40, "Live editor screenshot placeholder", font(34), GREY)
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

    # 15. Platform coverage (from architecture SVG if cairosvg available, else Pillow)
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
     "Change the platform to Kube-Virt and the schema adapts instantly. "
     "BMC fields disappear. Kube-Virt-specific options appear. "
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
    ("12-demo-cli",
     "The same templates work from the command line. "
     "Run process dot py with a template and a clusterfile, "
     "and get the rendered output instantly. "
     "No browser needed. Perfect for CI/CD pipelines and automation.",
     10),
    ("13-numbers",
     "187 fields in, 1,049 fields out. "
     "A 5.6 times expansion in structured data. "
     "267 input lines become 2,579 output lines across 11 templates. "
     "That's a 9.7 times line expansion.",
     15),
    ("14-time-cost",
     "First cluster: six hours manual, thirty minutes with Clusterfile. "
     "92 percent savings. "
     "A ten-cluster engagement saves forty-five hundred dollars in consulting time. "
     "Switching deployment methods takes one minute instead of four hours.",
     12),
    ("15-architecture",
     "11 platforms, 6 deployment methods, 6 operator plugins, 134 automated tests. "
     "From AWS to baremetal to Kube-Virt. "
     "Agent-based, IPI, ACM ZTP, CAPI, UPI, and SiteConfig.",
     10),
    ("16-cta",
     "Try it now. One container, one command. "
     "Pull the image, open localhost eight-thousand, load a sample, "
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
    # Standard arrow cursor polygon (outer black outline)
    outer = [(0, 0), (0, 32), (9, 24), (15, 37), (21, 34), (15, 21), (25, 21)]
    draw.polygon(outer, fill=(0, 0, 0, 255))
    # Inner white fill (slightly inset)
    inner = [(2, 4), (2, 27), (10, 21), (16, 33), (19, 31), (13, 19), (22, 19)]
    draw.polygon(inner, fill=(255, 255, 255, 255))
    return img

def add_click_indicator(clip, click_x, click_y):
    """Add animated cursor fade-in + click ripple overlay to an ImageClip.

    Timeline:
      t=0.0-0.3s  cursor fades in (alpha 0 -> 1)
      t=0.3-0.6s  click ripple (expanding circle, alpha 1 -> 0)
      t=0.6s-end  cursor stays visible, no ripple
    """
    import numpy as np
    from moviepy import VideoClip

    cursor_pil = create_cursor_image()
    cursor_arr = np.array(cursor_pil)  # HxWx4 RGBA
    base_frame = clip.get_frame(0).copy()
    duration = clip.duration

    def _overlay_cursor(frame, alpha_mult):
        """Alpha-composite cursor onto frame at (click_x, click_y)."""
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
        """Draw expanding white circle ripple centred at click position."""
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

    # Pre-render the static frame (cursor fully visible, no ripple) for t >= 0.6
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

        # Add click indicator overlay for demo slides (06-11)
        if slide_name in DEMO_CLICK_POSITIONS:
            cx, cy = DEMO_CLICK_POSITIONS[slide_name]
            clip = add_click_indicator(clip, cx, cy)
            print(f"  {slide_name}: +cursor at ({cx},{cy})")

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
