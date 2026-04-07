---
name: ship-it
description: Ship changes in the clusterfile repo safely. Use when preparing a change for production by validating diffs, handling local-only untracked files, merging a feature branch to main, pushing main, or performing the versioned Clusterfile Editor release flow.
---

# Ship It

Use this skill when the goal is "get this into prod" for the `clusterfile` repo.

Shipping is not just `git push`. In this repo, a solid ship includes:

- focused testing
- explicit behavior verification
- prompt history capture in `prompt.log`
- changelog updates
- version synchronization
- commit/tag/push
- release script or equivalent runtime steps
- deployment verification

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
- For renderer changes, verify real rendered output, not only unit tests.
- Prefer both automated checks and one direct runtime proof.

4. Review the exact release payload.
- `git diff --stat`
- `git diff -- <paths>`

5. Update release records before commit.
- Append the user prompts for the session to `prompt.log`.
- Update release notes in the changelog locations that apply.
- If shipping the editor release, sync all version-bearing files before the release commit.

## Required Records

These records are part of a production-quality ship in this repo.

1. `prompt.log`
- Add each user prompt from the session verbatim when possible.
- Include a short summary of what changed and what was verified.
- Treat this as part of the shipping workflow, not an optional cleanup pass.

2. `CHANGELOG.md`
- Add or update the repo-level release entry.
- Keep the entry concise and product-facing.

3. `apps/editor/static/changelog.md`
- Add the same release at the top with readable bullets.
- Do not leave raw git subjects unedited if they are unclear.

4. `apps/editor/static/js/app.js`
- Update `APP_VERSION`.
- Update the `CHANGELOG` array so the UI matches the shipped release.

5. `apps/editor/APP_VERSION` and `apps/editor/Containerfile`
- Keep them in sync with the release version and container build example.

## Branch-To-Main Flow

Use this when "ship it" means "merge to `main` and push prod."

1. Commit the intended change on the working branch.
- Stage only the files that belong in the ship.
- Keep local-only untracked files out of the commit.
- Include prompt log and changelog/version updates when those are part of the repo's release expectations.

2. Move to `main` and merge the feature branch.
- Prefer a non-interactive merge.
- Do not rewrite history unless explicitly requested.
- Confirm the feature branch does not contain older unshipped work unless the user explicitly wants the full branch promoted.

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

3. Update `prompt.log`.
- Capture the prompts that led to the shipped release.
- Note tests run, verification performed, and final release outcome.

4. Commit release metadata.
- Commit message pattern: `Release vX.Y.Z`

5. Tag release.
- Annotated tag: `vX.Y.Z`

6. Push commit and tag.

7. Build and push the editor image.
- Push both `quay.io/dds/clusterfile-editor:vX.Y.Z`
- And `quay.io/dds/clusterfile-editor:latest`

8. Run the deployment script or equivalent runtime command.
- Historical flow uses the release script plus container runtime operations.
- If there are helper scripts for load/run/package, use the repo-provided scripts instead of ad hoc commands when they fit.

9. Verify deployment health.
- `curl -s http://localhost:8000/healthz`

10. Verify the deployed version matches the released version.
- Health endpoint version should equal `APP_VERSION` and the git tag.

## Important Release Caveats

The historical release script is useful, but not fully hands-off.

- `apps/editor/static/js/app.js` has a manual changelog array that must stay in sync with the release.
- `apps/editor/static/changelog.md` should contain a readable summary, not just raw commit messages.
- `prompt.log` has historically been part of the release discipline and should be updated proactively.
- Avoid interactive tooling surprises. If the release flow invokes an editor, set a non-interactive editor or prepare release notes first.
- Confirm the branch target before pushing. A release from the wrong branch is worse than a delayed release.
- Verify whether `prompt.log` is meant to be committed in the current repo state or kept local-only; follow the repo's current tracking behavior rather than assuming.

## Testing And Verification Gate

Do not call it shipped until both of these are addressed:

1. Testing
- Run targeted tests for the changed area.
- If full tests are feasible, run them before release.
- If tooling is missing, say exactly what was blocked.

2. Verification
- Demonstrate the changed behavior directly.
- For UI or renderer changes, use a real render, API response, or runtime output.
- For release/deploy changes, verify service health and version after restart.

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

5. Scripts were used intentionally.
- Prefer repo scripts like `clusterfile-editor.sh`, `scripts/run.sh`, `scripts/load.sh`, or other project helpers when they match the workflow.
- Do not reimplement a known release or runtime workflow manually unless the script is broken or the user asked for a manual path.

## Clusterfile-Specific Guidance

- Treat `install-config.yaml.tpl` and installer-facing output as stricter than generic `kubectl apply` manifests.
- Keep CLI and web editor rendering behavior aligned.
- When changing shared rendering code, verify both installer-oriented output and apply-oriented output.
- Favor metadata-driven rendering behavior over filename-specific exceptions.

## Output

When using this skill, report:

1. What mode was used.
2. What was validated.
3. What was verified directly.
4. Which records were updated:
- `prompt.log`
- changelogs
- version files
5. What was merged or released.
6. Whether production push happened.
7. Whether image tags and runtime deployment happened.
8. Any manual follow-up still needed.
