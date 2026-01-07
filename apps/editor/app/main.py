from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from pathlib import Path
from pydantic import BaseModel
from typing import List, Optional
import json

from app.template_processor import render_template, list_templates, get_template_content

app = FastAPI(title="Clusterfile Editor", version="1.0.3")

class RenderRequest(BaseModel):
    yaml_text: str
    template_name: str
    params: Optional[List[str]] = []

# Disable CORS. Do not remove this for full-stack development.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

import os

BASE_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = Path("/app")
STATIC_DIR = BASE_DIR / "static"

SAMPLES_DIR = Path(os.environ.get("SAMPLES_DIR", str(REPO_ROOT / "samples")))
TEMPLATES_DIR = Path(os.environ.get("TEMPLATES_DIR", str(REPO_ROOT / "templates")))
SCHEMA_DIR = Path(os.environ.get("SCHEMA_DIR", str(REPO_ROOT / "schema")))

@app.get("/healthz")
async def healthz():
    return {"status": "ok"}

@app.get("/api/schema")
async def get_schema():
    schema_path = SCHEMA_DIR / "clusterfile.schema.json"
    if not schema_path.exists():
        raise HTTPException(status_code=404, detail="Schema not found")
    with open(schema_path, "r") as f:
        return JSONResponse(content=json.load(f))

@app.get("/api/samples")
async def list_samples():
    if not SAMPLES_DIR.exists():
        return {"samples": []}
    samples = []
    for f in SAMPLES_DIR.glob("*.clusterfile"):
        samples.append({"name": f.stem, "filename": f.name})
    return {"samples": samples}

@app.get("/api/samples/{filename}")
async def get_sample(filename: str):
    sample_path = SAMPLES_DIR / filename
    if not sample_path.exists():
        raise HTTPException(status_code=404, detail="Sample not found")
    with open(sample_path, "r") as f:
        return {"filename": filename, "content": f.read()}

@app.get("/api/templates")
async def get_templates():
    templates = list_templates(TEMPLATES_DIR)
    return {"templates": templates}

@app.get("/api/templates/{template_name}")
async def get_template(template_name: str):
    result = get_template_content(template_name, TEMPLATES_DIR)
    if not result["success"]:
        raise HTTPException(status_code=404, detail=result["error"])
    return {"name": template_name, "content": result["content"]}

@app.post("/api/render")
async def render(request: RenderRequest):
    result = render_template(
        yaml_text=request.yaml_text,
        template_name=request.template_name,
        params=request.params or [],
        templates_dir=TEMPLATES_DIR
    )
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return result

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

@app.get("/", response_class=HTMLResponse)
async def root():
    index_path = STATIC_DIR / "index.html"
    if index_path.exists():
        return FileResponse(index_path)
    return HTMLResponse(content="<h1>Clusterfile Editor</h1><p>Frontend not found</p>")
