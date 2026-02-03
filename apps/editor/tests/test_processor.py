"""Tests for the template processor module."""
import pytest
from pathlib import Path
import os

from app.template_processor import (
    load_file,
    base64encode,
    apply_params,
    coerceValue,
    cleanObject,
    _set_by_path,
    render_template,
    list_templates,
    get_template_content
)

TEST_DIR = Path(__file__).parent
REPO_ROOT = TEST_DIR.parent.parent.parent
TEMPLATES_DIR = REPO_ROOT / "templates"


class TestLoadFile:
    """Tests for load_file function."""

    def test_returns_placeholder_for_path(self):
        result = load_file("/path/to/file.txt")
        assert result == "<file:/path/to/file.txt>"

    def test_returns_empty_for_none(self):
        result = load_file(None)
        assert result == ""

    def test_returns_empty_for_empty_string(self):
        result = load_file("")
        assert result == ""

    def test_returns_empty_for_non_string(self):
        result = load_file(123)
        assert result == ""


class TestBase64Encode:
    """Tests for base64encode function."""

    def test_encodes_string(self):
        result = base64encode("hello")
        assert result == "aGVsbG8="

    def test_encodes_bytes(self):
        result = base64encode(b"hello")
        assert result == "aGVsbG8="

    def test_encodes_unicode(self):
        result = base64encode("héllo")
        assert result == "aMOpbGxv"


class TestApplyParams:
    """Tests for apply_params function."""

    def test_simple_override(self):
        data = {"cluster": {"name": "original"}}
        result = apply_params(data, ["cluster.name=new"])
        assert result["cluster"]["name"] == "new"

    def test_jsonpath_override(self):
        data = {"cluster": {"name": "original"}}
        result = apply_params(data, ["$.cluster.name=new"])
        assert result["cluster"]["name"] == "new"

    def test_nested_path_creation(self):
        data = {}
        result = apply_params(data, ["cluster.nested.value=test"])
        assert result["cluster"]["nested"]["value"] == "test"

    def test_array_index(self):
        data = {"items": ["a", "b", "c"]}
        result = apply_params(data, ["items[1]=updated"])
        assert result["items"][1] == "updated"

    def test_empty_params(self):
        data = {"key": "value"}
        result = apply_params(data, [])
        assert result == {"key": "value"}

    def test_invalid_param_ignored(self):
        data = {"key": "value"}
        result = apply_params(data, ["invalid_no_equals"])
        assert result == {"key": "value"}


class TestSetByPath:
    """Tests for _set_by_path function."""

    def test_simple_key(self):
        doc = {}
        _set_by_path(doc, "key", "value")
        assert doc["key"] == "value"

    def test_nested_keys(self):
        doc = {}
        _set_by_path(doc, "a.b.c", "value")
        assert doc["a"]["b"]["c"] == "value"

    def test_array_index(self):
        doc = {"items": []}
        _set_by_path(doc, "items[0]", "first")
        assert doc["items"][0] == "first"

    def test_auto_expand_array(self):
        doc = {"items": []}
        _set_by_path(doc, "items[2]", "third")
        assert len(doc["items"]) == 3
        assert doc["items"][2] == "third"

    def test_strip_dollar_prefix(self):
        doc = {}
        _set_by_path(doc, "$.key", "value")
        assert doc["key"] == "value"

    def test_strip_leading_dot(self):
        doc = {}
        _set_by_path(doc, ".key", "value")
        assert doc["key"] == "value"


class TestListTemplates:
    """Tests for list_templates function."""

    def test_returns_list(self):
        if TEMPLATES_DIR.exists():
            result = list_templates(TEMPLATES_DIR)
            assert isinstance(result, list)

    def test_template_has_name_and_description(self):
        if TEMPLATES_DIR.exists():
            result = list_templates(TEMPLATES_DIR)
            for template in result:
                assert "name" in template
                assert "description" in template

    def test_nonexistent_dir_returns_empty(self):
        result = list_templates(Path("/nonexistent"))
        assert result == []


class TestGetTemplateContent:
    """Tests for get_template_content function."""

    def test_returns_content_for_existing_template(self):
        if TEMPLATES_DIR.exists():
            templates = list_templates(TEMPLATES_DIR)
            if templates:
                name = templates[0]["name"]
                result = get_template_content(name, TEMPLATES_DIR)
                assert result["success"] is True
                assert "content" in result

    def test_returns_error_for_nonexistent_template(self):
        result = get_template_content("nonexistent.tpl", TEMPLATES_DIR)
        assert result["success"] is False
        assert "error" in result

    def test_rejects_path_traversal(self):
        result = get_template_content("../../../etc/passwd", TEMPLATES_DIR)
        assert result["success"] is False


class TestRenderTemplate:
    """Tests for render_template function."""

    def test_returns_error_for_invalid_yaml(self):
        result = render_template(
            yaml_text="invalid: yaml: :",
            template_name="test.tpl",
            params=[],
            templates_dir=TEMPLATES_DIR
        )
        assert result["success"] is False
        assert "Invalid YAML" in result["error"]

    def test_returns_error_for_missing_template(self):
        result = render_template(
            yaml_text="key: value",
            template_name="nonexistent.tpl",
            params=[],
            templates_dir=TEMPLATES_DIR
        )
        assert result["success"] is False
        assert "not found" in result["error"]

    def test_rejects_path_traversal_in_template_name(self):
        result = render_template(
            yaml_text="key: value",
            template_name="../../../etc/passwd",
            params=[],
            templates_dir=TEMPLATES_DIR
        )
        assert result["success"] is False
        assert "Invalid template name" in result["error"]
