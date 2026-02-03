"""
Clusterfile Editor v2.0 - FastAPI Backend

A schema-driven, offline-first web editor for OpenShift cluster configuration files.
"""
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse, Response
from pathlib import Path
from pydantic import BaseModel
from typing import List, Optional
import json
import os

from app.template_processor import render_template, list_templates, get_template_content

# Read version from APP_VERSION file
VERSION_FILE = Path(__file__).resolve().parent.parent / "APP_VERSION"
VERSION = VERSION_FILE.read_text().strip() if VERSION_FILE.exists() else "2.0.0"

app = FastAPI(
    title="Clusterfile Editor",
    version=VERSION,
    description="Schema-driven, offline-first web editor for OpenShift cluster configuration files"
)


class RenderRequest(BaseModel):
    """Request model for template rendering."""
    yaml_text: str
    template_name: str
    params: Optional[List[str]] = []


# Content Security Policy for offline-first security
# Note: 'unsafe-eval' required for AJV JSON Schema validation (uses new Function())
CSP_HEADER = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-eval'; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data:; "
    "connect-src 'self'; "
    "frame-ancestors 'none'; "
    "base-uri 'self'; "
    "form-action 'self'"
)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Add security headers to all responses."""
    response = await call_next(request)
    response.headers["Content-Security-Policy"] = CSP_HEADER
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response


# CORS configuration - restricted for production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

# Directory configuration
BASE_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = Path("/app")
STATIC_DIR = BASE_DIR / "static"

SAMPLES_DIR = Path(os.environ.get("SAMPLES_DIR", str(REPO_ROOT / "samples")))
TEMPLATES_DIR = Path(os.environ.get("TEMPLATES_DIR", str(REPO_ROOT / "templates")))
SCHEMA_DIR = Path(os.environ.get("SCHEMA_DIR", str(REPO_ROOT / "schema")))


@app.get("/healthz")
async def healthz():
    """Health check endpoint."""
    return {"status": "ok", "version": VERSION}


@app.get("/api/schema")
async def get_schema():
    """Return the clusterfile JSON schema."""
    schema_path = SCHEMA_DIR / "clusterfile.schema.json"
    if not schema_path.exists():
        raise HTTPException(status_code=404, detail="Schema not found")
    with open(schema_path, "r") as f:
        return JSONResponse(content=json.load(f))


@app.get("/api/samples")
async def list_samples():
    """List all available sample clusterfiles."""
    if not SAMPLES_DIR.exists():
        return {"samples": []}
    samples = []
    for f in sorted(SAMPLES_DIR.glob("*.clusterfile")):
        samples.append({"name": f.stem, "filename": f.name})
    return {"samples": samples}


@app.get("/api/samples/{filename}")
async def get_sample(filename: str):
    """Get the content of a specific sample clusterfile."""
    # Security: prevent path traversal
    safe_name = os.path.basename(filename)
    if safe_name != filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")

    sample_path = SAMPLES_DIR / filename
    if not sample_path.exists():
        raise HTTPException(status_code=404, detail="Sample not found")
    with open(sample_path, "r") as f:
        return {"filename": filename, "content": f.read()}


@app.get("/api/templates")
async def get_templates():
    """List all available Jinja2 templates."""
    templates = list_templates(TEMPLATES_DIR)
    return {"templates": templates}


@app.get("/api/templates/{template_name}")
async def get_template(template_name: str):
    """Get the content of a specific template."""
    result = get_template_content(template_name, TEMPLATES_DIR)
    if not result["success"]:
        raise HTTPException(status_code=404, detail=result["error"])
    return {"name": template_name, "content": result["content"]}


@app.post("/api/render")
async def render(request: RenderRequest):
    """Render a Jinja2 template with YAML data and optional parameter overrides."""
    result = render_template(
        yaml_text=request.yaml_text,
        template_name=request.template_name,
        params=request.params or [],
        templates_dir=TEMPLATES_DIR
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


# Mount static files
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/", response_class=HTMLResponse)
async def root():
    """Serve the main application."""
    index_path = STATIC_DIR / "index.html"
    if index_path.exists():
        return FileResponse(index_path)
    return HTMLResponse(content=f"<h1>Clusterfile Editor v{VERSION}</h1><p>Frontend not found</p>")
