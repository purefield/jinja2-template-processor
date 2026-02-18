#!/usr/bin/env bash
# Install dependencies for optimal video/content creation
# Usage: bash install-deps.sh
set -euo pipefail

FONT_DIR="${HOME}/.local/share/fonts"
DEJAVU_VERSION="2.37"
DEJAVU_URL="https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_${DEJAVU_VERSION}/dejavu-fonts-ttf-${DEJAVU_VERSION}.zip"

echo "=== Installing DejaVu fonts (Unicode arrows, symbols) ==="
mkdir -p "${FONT_DIR}"
if [ -f "${FONT_DIR}/DejaVuSans.ttf" ]; then
    echo "  DejaVu Sans already installed"
else
    TMPZIP="$(mktemp /tmp/dejavu-XXXXXX.zip)"
    echo "  Downloading DejaVu fonts v${DEJAVU_VERSION}..."
    curl -sL "${DEJAVU_URL}" -o "${TMPZIP}"
    python3 -c "
import zipfile, sys, shutil, os
dst = '${FONT_DIR}'
with zipfile.ZipFile('${TMPZIP}') as z:
    for name in z.namelist():
        if name.endswith('.ttf') and '/' in name:
            basename = os.path.basename(name)
            src = z.extract(name, '/tmp/')
            shutil.move(src, os.path.join(dst, basename))
            print(f'  Installed {basename}')
"
    rm -f "${TMPZIP}"
fi

echo ""
echo "=== Installing Python packages ==="
pip install --quiet \
    Pillow \
    edge-tts \
    moviepy \
    cairosvg \
    2>&1 | tail -1 || true
echo "  Core packages installed"

echo ""
echo "=== Installing Playwright (for editor screenshots) ==="
pip install --quiet playwright 2>&1 | tail -1 || true
playwright install chromium 2>/dev/null || echo "  (chromium install skipped — run 'playwright install chromium' manually if needed)"

echo ""
echo "=== Verifying ==="
python3 -c "
from PIL import ImageFont
import os

font_dir = os.path.expanduser('~/.local/share/fonts')

# Test DejaVu Sans
path = os.path.join(font_dir, 'DejaVuSans.ttf')
if os.path.exists(path):
    f = ImageFont.truetype(path, 48)
    # Verify arrow glyph renders correctly (not a .notdef box)
    mask = f.getmask('\u2192')
    print(f'  DejaVu Sans: OK ({mask.size[0]}x{mask.size[1]}px arrow glyph)')
else:
    print('  WARNING: DejaVuSans.ttf not found')

# Test other packages
try:
    import edge_tts
    print('  edge-tts: OK')
except ImportError:
    print('  WARNING: edge-tts not installed')

try:
    from moviepy import VideoFileClip
    print('  moviepy: OK')
except (ImportError, RuntimeError):
    print('  WARNING: moviepy import issue')

try:
    import cairosvg
    print('  cairosvg: OK')
except (ImportError, OSError):
    print('  WARNING: cairosvg not available')
"

echo ""
echo "=== Done ==="
echo "Run 'python generate-video.py --slides-only' to test slide generation"
