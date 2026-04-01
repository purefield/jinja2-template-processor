---
name: clusterfile-authoring
description: Work correctly with the clusterfile project schema, templates, plugins, and rendering model. Use when changing clusterfile data shape, generic templates, plugin manifests, docs, or tests in the clusterfile repo.
---

# Clusterfile Authoring

Use this skill when working inside the `clusterfile` repo.

## Boundary

- `clusterfile` is generic and public.
- Do not add lab-only, ACM-only, or site-specific conventions here.
- Keep environment-specific behavior in the consuming repo.

## Core Areas

- schema
- data examples
- templates
- plugins
- tests
- docs that explain generic behavior

## Working Rules

1. Keep data generic.
- Model intent, not lab wiring.
- Avoid hardcoding site-specific paths, hosts, or secret naming.

2. Keep plugins domain-based.
- A plugin should describe a generic capability such as auth, cert-manager, storage, or registry.
- Do not make a plugin for a single lab workaround.

3. Keep templates reusable.
- Prefer configurable fields over embedded environment assumptions.
- Keep public contracts stable when possible.

4. Keep tests aligned.
- When changing a schema, template, or plugin, update tests in the same change.
- Prefer tests that assert generic behavior, not one lab's values.

5. Keep rendering explicit.
- Make it clear which fields are rendered from cluster data and which are left to consuming repos.

## Anti-Patterns

- Adding `openshift/`, `ola`, or other site-specific conventions to generic templates.
- Using clusterfile to solve a problem that belongs in a local orchestration repo.
- Hiding breaking template changes without updating examples and tests.

## Output Style

Lead with whether the change belongs in `clusterfile` at all. If it does, name the smallest generic contract that supports it.
