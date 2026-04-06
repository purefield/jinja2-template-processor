---
name: ship-it
description: Ship changes in the clusterfile repo safely. Use when preparing a change for production by validating diffs, handling local-only untracked files, merging a feature branch to main, pushing main, or performing the versioned Clusterfile Editor release flow.
---

# Ship It

Use this skill when the goal is "get this into prod" for the `clusterfile` repo.

## Modes

Pick the release mode first.

1. Branch-to-main ship
- Use when production is driven by `main`.
- Typical flow: validate, commit on feature branch, merge into `main`, push `main`.

2. Versioned editor release
- Use when shipping a tagged Clusterfile Editor image and updating release notes.
- The historical entry point is `./clusterfile-editor.sh release`.

## Preflight

Before changing branches or tagging:

1. Check current branch and worktree state.
- `git branch --show-current`
- `git status --short --branch --untracked-files=all`

2. Separate tracked work from local-only files.
- Do not commit local scratch files like `.codex/` or ad hoc notes unless explicitly requested.
- Prefer leaving local-only files untracked.
- If they are noisy, use a local exclude mechanism, not repo-wide `.gitignore`, unless the whole team wants the ignore rule.

3. Validate the change at the right level.
- Run focused tests when available.
- If the environment is missing dependencies, do lightweight verification that still proves the behavioral change.
- Record what was verified and what could not be run.

4. Review the exact release payload.
- `git diff --stat`
- `git diff -- <paths>`

## Branch-To-Main Flow

Use this when "ship it" means "merge to `main` and push prod."

1. Commit the intended change on the working branch.
- Stage only the files that belong in the ship.
- Keep local-only untracked files out of the commit.

2. Move to `main` and merge the feature branch.
- Prefer a non-interactive merge.
- Do not rewrite history unless explicitly requested.

3. Re-check the merged result on `main`.
- `git status --short --branch`
- Run the same focused verification again if the merge changed anything non-trivial.

4. Push `main`.
- This is the production step when the repo deploys from `main`.

5. Cleanup after a successful push.
- Optionally delete the merged local branch if the user wants cleanup.
- Do not delete the branch before confirming push success.

## Versioned Editor Release Flow

Historical release behavior is codified in `clusterfile-editor.sh`.

The script's intended flow is:

1. Bump version.
- `./clusterfile-editor.sh release patch|minor|major|x.y.z`

2. Sync release version across:
- `apps/editor/APP_VERSION`
- `apps/editor/Containerfile`
- `CHANGELOG.md`
- `apps/editor/static/changelog.md`
- `apps/editor/static/js/app.js`

3. Commit release metadata.
- Commit message pattern: `Release vX.Y.Z`

4. Tag release.
- Annotated tag: `vX.Y.Z`

5. Push commit and tag.

6. Build and push the editor image.
- Push both `quay.io/dds/clusterfile-editor:vX.Y.Z`
- And `quay.io/dds/clusterfile-editor:latest`

7. Restart the running editor container.

8. Verify deployment health.
- `curl -s http://localhost:8000/healthz`

## Important Release Caveats

The historical release script is useful, but not fully hands-off.

- `apps/editor/static/js/app.js` has a manual changelog array that must stay in sync with the release.
- `apps/editor/static/changelog.md` should contain a readable summary, not just raw commit messages.
- Avoid interactive tooling surprises. If the release flow invokes an editor, set a non-interactive editor or prepare release notes first.
- Confirm the branch target before pushing. A release from the wrong branch is worse than a delayed release.

## Product-Quality Bar

Before calling it shipped, make sure:

1. The behavior change is demonstrated, not just reasoned about.
- Example: render output changed as intended.

2. User-facing docs or release notes mention the change when relevant.

3. The release artifact path is clear.
- Main push
- Tag
- Container image
- Running service

4. Any missing verification is called out explicitly.

## Clusterfile-Specific Guidance

- Treat `install-config.yaml.tpl` and installer-facing output as stricter than generic `kubectl apply` manifests.
- Keep CLI and web editor rendering behavior aligned.
- When changing shared rendering code, verify both installer-oriented output and apply-oriented output.
- Favor metadata-driven rendering behavior over filename-specific exceptions.

## Output

When using this skill, report:

1. What mode was used.
2. What was validated.
3. What was merged or released.
4. Whether production push happened.
5. Any manual follow-up still needed.
