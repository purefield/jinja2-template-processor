**Consolidated Requirements — .clusterfile Editor**

Purpose
- **Goal**: Build a best-in-class, schema-driven, offline-first .clusterfile editor that supports strict YAML round-trip (minimal-diff saves), two-way YAML ↔ form sync, AJV validation, change-tracking with per-change revert, PatternFly styling, and documentation bubbles for each field. The app must work for both VMware admins and Linux engineers.

**Backend**
- **Schema Management**: Single canonical `clusterfile.schema.json` in the repo (source of truth). Allow user-uploaded schema only locally (persist in `localStorage` as `CLUSTERFILE_UPLOADED_SCHEMA`) but do not treat uploaded schemas as shared or authoritative.

- **Validation Engine**: Use AJV (client) with format-checkers (ipv4/cidr/mac/uri). Client-side validation is sufficient (`process.py` already validates server/CI-side), and support validation runs for "data" (before overrides) and "data+params" (after overrides).

- **Round-Trip & Patching**: Comments and exact comment preservation are NOT required (files are machine-use only). Implement a minimal-text patching strategy focused on minimal diffs and preserving formatting where practical. Maintain three canonical states: `baselineYamlText`, `currentYamlText`, `currentObject`.

- **Template Rendering Integration**: Keep `process.py` compatibility (Jinja2). The backend must detect `x-is-file` fields and treat them as filesystem paths (templates call `load_file`). In-browser template rendering is not required for the first pass (document CLI `process.py` workflow); plan for future in-browser rendering support.

- **Offline Packaging and Vendoring**: Vendor only required runtime libs into `clusterfile-editor/vendor/` (AJV, CodeMirror v5 (stable), json-editor or chosen form library, js-yaml or small YAML helper, diff lib). Provide `schema_embedded.js` and `samples_embedded.js` fallbacks so app runs under `file://`.

- **Persistence & APIs**: Local-only persistence (localStorage) for uploaded schema, custom samples, and `LAST_YAML`. Do not persist secrets or `x-is-file` contents. Provide an optional containerized local server image (container with a simple static webserver) and document `python -m http.server` as an alternative.

- **Security & Secrets**: Treat `x-is-file` fields and known secrets (`pullSecret`, BMC passwords) as sensitive. Never inline file contents into the YAML; do not persist secrets in `LAST_YAML` or other localStorage keys. Redact secrets from debug views and logs; warn users about localStorage insecurity but do not provide client-side encryption for V1.

- **Testing & CI**: Unit tests for YAML helpers, AJV rules, and patch application. Integration (headless) tests for two-way sync, add/remove arrays, revert flows. Provide CI job examples (GitHub Actions) but keep tests runnable locally.

**UI**
- **Layout & Shell (PatternFly)**: Use the specified shell optimized for medium screen resolutions. Left-nav: Account → Cluster → Network → Hosts → Plugins. Header with Load/Save/Download controls. Main split pane: left form sections, right YAML editor top 60% + bottom 40% tabs (Validation, Errors/Debug, Changes). Hosts render as collapsible cards (name shown) and card order is not significant. Support copy/duplicate host helper.

- **Schema-Driven Form**: Generate UI per top-level sections from schema. Support objects, arrays (add/remove/reorder), `oneOf`/`anyOf` with explicit UI (dropdown + Custom), and patternProperties for `hosts` as collapsible host-cards keyed by hostname. Provide a host-copy/duplicate helper to quickly create similar hosts (mac, name, IP editable). Limit UI scale to ~16 hosts and optimize for that.

- **YAML Editor**: Use CodeMirror v5 (stable and easy to vendor) with YAML lint. Form-to-YAML applies targeted minimal patches to keep diffs small; full comment preservation is not a priority.

- **Validation & Error Tabs**: Validation tab shows AJV errors with JSON Pointer and friendly message. Errors/Debug tab shows YAML parse errors, internal events, and metrics (parse time, validation time, last diff size, total changes count). All debug outputs redact secrets.

- **Help Bubbles**: Hover ≥ 2s shows description + `x-doc-url` links (prefer 4.20, fallback 4.19). Bubbles are clickable and can be pinned open for copy/paste and link selection.

- **File Widgets**: For `x-is-file` fields, render a path input. Do NOT inline file contents into the YAML (secrets). Always store paths as strings.

- **Change Indicators & Revert**: Per-field change indicator used as a revert control (visual similar to Bambu Lab Studio). Provide undo/redo navigation with a history list and arrows to step backward/forward; maintain browser undo/redo stack where practical.

- **Host/Network Advanced Widgets**: Provide helpers useful to VMware admins (VLAN picker, NIC suggestions). Allow copy/duplicate hosts with mac, name, and IP editable.

- **Accessibility & Keyboard**: Keyboard navigation, aria labels, screen-reader friendly errors. Compact PatternFly spacing.
  - Questions: Any specific accessibility standards to enforce beyond standard ARIA (WCAG 2.1 AA)?

**UX (Personas: VMware Admin & Linux Engineer)**
- **Modes**: Provide two modes: "Guided" (form-first) and "Advanced" (raw YAML). Default to "Guided" for first-time users.

- **Onboarding & Defaults**: On first run, show a quick tour. Provide "Start from example" with `customer*` samples. Offer sample-driven quickstarts optional in a later iteration.

- **Error Handling**: Show errors but do not block Save/Download; warn users prominently on validation failures.

- **Performance & Scale**: Target scale is modest — up to 16 hosts. Lazy-render host cards and optimize for responsive medium-screen layouts.

- **Diff-Focused Saves**: Downloads should be minimal diffs relative to baseline. Provide a diff preview in unified `diff -u` or GitHub-style format.

**Non-Functional & Operational**
- **Offline-Only Guarantee**: No CDN or external runtime fetches; vendor all assets. Provide `schema_embedded.js` and `samples_embedded.js` for `file://` fallback.
- **Packaging**: Deliver as a static folder `clusterfile-editor/` that can be served via `file://` or `http://`. Provide an optional containerized image (Podman/Podman-compose or similar) that serves the static site for easy localhost deployment.
- **Browser Support**: Modern Chrome/Edge/Firefox (latest 2 versions). Mobile support optional.
- **Telemetry**: No telemetry by default. If added later, opt-in and locally configurable.

**Acceptance Criteria (concise)**
- Two-way YAML ↔ form sync works reliably for all tested fields.
- Validation (AJV) surfaces the same constraints as `clusterfile.schema.json` with helpful messages.
- Minimal-diff save behavior: only edited fields are changed in the file; key order/comments preserved where feasible.
- Offline operation with vendored assets and embedded schema/samples.
- Revert workflows (per-field, section, all) restore baseline reliably.
- Host patternProperties rendered as collapsible host-cards with add/remove, copy/duplicate host helper, and hostname validation. Card order is not significant; cards can be collapsed to show only the host name.

**Deliverables & Files to Create**
- `clusterfile-editor/` static app: `index.html`, `app.js`, `app.css`, `vendor/` (AJV, CodeMirror, json-editor, js-yaml or rt-yaml, diff lib)
- Repo schema artifacts: `clusterfile.schema.json`, `clusterfile.openapi.yaml`, `SCHEMA_NOTES.md` (mapping to templates and process.py)
- `samples/` directory with only `customer*` files and `samples_embedded.js`
- `README.md` with run instructions and local server guidance
- Tests: `tests/unit/` and `tests/integration/` (headless)

**Next Steps & Questions (prioritization for implementation)**
1. Confirm comment-preservation priority: full round-trip YAML library vs targeted patching.
2. Confirm default CodeMirror version and form library choice (`json-editor` vanilla vs `react-jsonschema-form`).
3. Confirm expected scale (max hosts) and whether an in-browser template preview is required.
4. Confirm whether user-uploaded schema should be shareable across users (out of scope for offline-only).

If you confirm answers to the questions above I will produce a prioritized implementation plan and prototype the first pass (vendor assets + mount `json-editor` for the `cluster` section with two-way sync and AJV validation). 

---
Progress: I read `SPEC.md` and `clusterfile-prompt.txt` and drafted this consolidated requirements document. Next: finalize and write this file to the repo (done). Tell me which items to prioritize or answer the questions above and I will start the prototype implementation.