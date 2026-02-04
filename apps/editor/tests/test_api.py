"""Tests for the Clusterfile Editor v2.0 API endpoints."""
import pytest
from fastapi.testclient import TestClient
from pathlib import Path
import json
import os

# Set up test environment
TEST_DIR = Path(__file__).parent
REPO_ROOT = TEST_DIR.parent.parent.parent

os.environ["SAMPLES_DIR"] = str(REPO_ROOT / "data")
os.environ["TEMPLATES_DIR"] = str(REPO_ROOT / "templates")
os.environ["SCHEMA_DIR"] = str(REPO_ROOT / "schema")

from app.main import app

client = TestClient(app)


class TestHealthEndpoint:
    """Tests for /healthz endpoint."""

    def test_healthz_returns_ok(self):
        response = client.get("/healthz")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "version" in data


class TestSchemaEndpoint:
    """Tests for /api/schema endpoint."""

    def test_get_schema_returns_valid_json_schema(self):
        response = client.get("/api/schema")
        assert response.status_code == 200
        schema = response.json()
        assert "$schema" in schema
        assert "properties" in schema
        assert "account" in schema["properties"]
        assert "cluster" in schema["properties"]
        assert "network" in schema["properties"]
        assert "hosts" in schema["properties"]


class TestSamplesEndpoint:
    """Tests for /api/samples endpoints."""

    def test_list_samples_returns_array(self):
        response = client.get("/api/samples")
        assert response.status_code == 200
        data = response.json()
        assert "samples" in data
        assert isinstance(data["samples"], list)

    def test_list_samples_has_expected_format(self):
        response = client.get("/api/samples")
        assert response.status_code == 200
        data = response.json()
        for sample in data["samples"]:
            assert "name" in sample
            assert "filename" in sample

    def test_get_sample_returns_content(self):
        # First get list of samples
        list_response = client.get("/api/samples")
        samples = list_response.json()["samples"]

        if samples:
            # Get first sample
            filename = samples[0]["filename"]
            response = client.get(f"/api/samples/{filename}")
            assert response.status_code == 200
            data = response.json()
            assert "filename" in data
            assert "content" in data
            assert data["filename"] == filename

    def test_get_nonexistent_sample_returns_404(self):
        response = client.get("/api/samples/nonexistent.clusterfile")
        assert response.status_code == 404

    def test_path_traversal_rejected(self):
        response = client.get("/api/samples/../../../etc/passwd")
        # Path traversal is blocked - 404 from router is acceptable security behavior
        assert response.status_code in (400, 404)


class TestTemplatesEndpoint:
    """Tests for /api/templates endpoints."""

    def test_list_templates_returns_array(self):
        response = client.get("/api/templates")
        assert response.status_code == 200
        data = response.json()
        assert "templates" in data
        assert isinstance(data["templates"], list)

    def test_list_templates_has_expected_format(self):
        response = client.get("/api/templates")
        assert response.status_code == 200
        data = response.json()
        for template in data["templates"]:
            assert "name" in template
            assert "description" in template

    def test_get_template_returns_content(self):
        # First get list of templates
        list_response = client.get("/api/templates")
        templates = list_response.json()["templates"]

        if templates:
            # Get first template - use filename (with .tpl extension) for the API
            filename = templates[0]["filename"]
            response = client.get(f"/api/templates/{filename}")
            assert response.status_code == 200
            data = response.json()
            assert "name" in data
            assert "content" in data
            assert data["name"] == filename

    def test_get_nonexistent_template_returns_404(self):
        response = client.get("/api/templates/nonexistent.tpl")
        assert response.status_code == 404


class TestRenderEndpoint:
    """Tests for /api/render endpoint."""

    def test_render_with_invalid_yaml_returns_400(self):
        response = client.post("/api/render", json={
            "yaml_text": "invalid: yaml: content:",
            "template_name": "test.tpl",
            "params": []
        })
        # Invalid YAML should fail or invalid template should fail
        assert response.status_code in [400, 404]

    def test_render_with_valid_yaml_and_template(self):
        # Get a real template
        list_response = client.get("/api/templates")
        templates = list_response.json()["templates"]

        if templates:
            template_name = templates[0]["name"]

            response = client.post("/api/render", json={
                "yaml_text": """
account:
  pullSecret: /path/to/pull-secret.json
cluster:
  name: test
  version: "4.20.0"
network:
  domain: example.com
hosts: {}
""",
                "template_name": template_name,
                "params": []
            })

            # Should either succeed or fail gracefully
            if response.status_code == 200:
                data = response.json()
                assert "success" in data
                assert "output" in data
            else:
                # Template may have specific requirements
                assert response.status_code == 400

    def test_render_with_params(self):
        list_response = client.get("/api/templates")
        templates = list_response.json()["templates"]

        if templates:
            template_name = templates[0]["name"]

            response = client.post("/api/render", json={
                "yaml_text": """
cluster:
  name: test
network:
  domain: example.com
hosts: {}
account: {}
""",
                "template_name": template_name,
                "params": ["$.cluster.name=overridden"]
            })

            # Should process (may succeed or fail based on template requirements)
            assert response.status_code in [200, 400]


class TestSecurityHeaders:
    """Tests for security headers."""

    def test_csp_header_present(self):
        response = client.get("/healthz")
        assert "content-security-policy" in response.headers
        csp = response.headers["content-security-policy"]
        assert "default-src 'self'" in csp
        assert "script-src 'self'" in csp

    def test_x_content_type_options(self):
        response = client.get("/healthz")
        assert response.headers.get("x-content-type-options") == "nosniff"

    def test_x_frame_options(self):
        response = client.get("/healthz")
        assert response.headers.get("x-frame-options") == "DENY"


class TestStaticFiles:
    """Tests for static file serving."""

    def test_root_serves_html(self):
        response = client.get("/")
        assert response.status_code == 200
        assert "text/html" in response.headers.get("content-type", "")

    def test_static_css_accessible(self):
        response = client.get("/static/css/app.css")
        assert response.status_code == 200

    def test_static_js_accessible(self):
        response = client.get("/static/js/app.js")
        assert response.status_code == 200
