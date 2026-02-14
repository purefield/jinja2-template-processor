# Jinja2 Template Processor

## Design principles

- **DRY** — Never repeat yourself. Extract shared blocks into includes. If two templates have identical logic, factor it out.
- **Small functions** — Every function should fit on a screen and be understandable at a glance.
- **Reduce lines** — Minimize lines of code and change sets when refactoring.
- **Commit early and often** — Meaningful commit messages, small focused commits.
- **Smart defaults and graceful degradation** — Error on the side of less user input. Use sensible defaults and degrade gracefully up to the point of failure when there's not enough information to succeed.

## Template formatting rules

- Jinja2 control blocks (`{% if %}`, `{% endif %}`, `{% for %}`, `{% endfor %}`) must NOT start on their own line. They go at the **end** of the preceding YAML line, inline.
- Use `{%- set ... -%}` (with whitespace trim) for variable assignments at the top of templates — these are the exception since they produce no output.
- `{%- if/elif/else/endif/for/endfor -%}` (with trim dashes on both sides) is only for variable-assignment blocks that must not emit whitespace.

### Correct

```jinja2
    name: {{ namespace }}{% if vlanId %}
    labels:
      vlan-{{ vlanId }}: ""{% endif %}{% if netType == "linux-bridge" %}
- kind: NetworkAttachmentDefinition{% endif %}{% for name, host in hosts.items() %}
```

### Incorrect

```jinja2
    name: {{ namespace }}
{%- if vlanId %}
    labels:
      vlan-{{ vlanId }}: ""
{%- endif %}
{%- if netType == "linux-bridge" %}
- kind: NetworkAttachmentDefinition
{%- endif %}
{% for name, host in hosts.items() %}
```

## Git rules

**All of the following are automatic** — do them proactively on every commit without being asked:

- **No history rewrites.** Never squash, rebase, amend, or force-push. Forward-only commits.
- **Tag each feature.** After committing a new feature or fix, create an annotated tag on its commit (e.g., `git tag -a feature-name <sha> -m "description"`). Push tags with `git push --tags`.
- **Capture every prompt.** After each user message, append the following to `prompt.log`:
  1. The prompt number (`### Prompt N`)
  2. The user's message verbatim in a blockquote (`> ...`)
  3. A short summary of what was done (changes, commits, tags, or explanation given)

  Do this for **every** prompt — not just feature work. Includes: questions, "commit", "ship it", "stop", corrections, config discussions. This is the audit trail of the entire session.
- **Maintain a changelog.** When committing a feature or notable fix, append an entry to `CHANGELOG.md` under an `## Unreleased` section. Each entry should include the tag name, a one-line summary, and the date. Move entries under a version heading when a release tag is created.
- **Keep versions in sync.** On release, update **all five** version locations together:
  1. `apps/editor/APP_VERSION` — the single source of truth for the app version
  2. `apps/editor/static/changelog.md` — human-readable markdown changelog
  3. `apps/editor/static/js/app.js` — `CHANGELOG` JavaScript array (rendered in-app)
  4. `CHANGELOG.md` — repo-level changelog
  5. `apps/editor/Containerfile` — version in header comment and build example

  The version in `APP_VERSION` must match the git release tag. Never leave these out of sync.
- **"Ship it" means the full release process:**
  1. Update all five version/changelog locations (see above)
  2. Commit, tag (`v<version>`), and `git push && git push --tags`
  3. Build the container: `podman build -t quay.io/dds/clusterfile-editor:v<version> -t quay.io/dds/clusterfile-editor:latest -f apps/editor/Containerfile .`
  4. Push both tags: `podman push quay.io/dds/clusterfile-editor:v<version>` and `podman push quay.io/dds/clusterfile-editor:latest`
  5. Restart the running app: `podman run -d --replace --network host --name clusterfile-editor quay.io/dds/clusterfile-editor:v<version>`
  6. Verify: `curl -s http://localhost:8000/healthz` should return the new version
  7. Update `prompt.log` with the session's prompts

## Cluster safety

- **NEVER apply resources to the `rlinks` cluster** (`api.rlinks.ola.purefield.nl:6443`, service account `rlinks-admin`). This is a **production environment**. Do not use `oc apply`, `oc delete`, or any mutating commands against it for this project, under any circumstances.
- Before running `oc apply` or any cluster-mutating command, always verify the current context and confirm it is a non-production target.

## Project structure

- `templates/` — Jinja2 templates (`.yaml.tpl`) for Kubernetes/OpenShift resource generation
- `templates/includes/` — Reusable template fragments
- `schema/clusterfile.schema.json` — JSON Schema for clusterfile validation
- `data/` — Example clusterfile data files
- `tests/` — pytest test suite

## KubeVirt networking

- The CUDN/NNCP infra templates (OVS bridge, bridge-mappings, CUDNs, linux-bridge NADs) are **standalone** and live outside this project (e.g., `/tmp/cudn-localnet/`). They are NOT part of the clusterfile schema.
- The per-cluster `kubevirt-cluster.yaml.tpl` only handles namespace labeling (`vlan-<id>`) and inline NAD creation for `linux-bridge` mode.
- `plugins.kubevirt.network.type` options: `cudn`, `linux-bridge`, `nad`.
