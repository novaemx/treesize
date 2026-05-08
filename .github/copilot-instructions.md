<!-- gitflow-version: 0.6.5 -->
# Copilot Instructions

## Gitflow Enforcement

**Before modifying ANY code, run the gitflow pre-flight check.**

```bash
gitflow --json status
```

### Pre-flight sequence

1. Check `git_flow_initialized` → if false, run `gitflow --json init`
2. Check `merge.in_merge` → if true, STOP and report to user
3. Check `main_ahead_of_develop` → if > 0, run `gitflow --json backmerge`
4. Ensure you are on the correct branch for the task type
5. NEVER modify code on main or develop directly — use flow branches
6. When done: `gitflow --json finish`

### Branch routing

| Task type    | Start command                                |
|-------------|----------------------------------------------|
| Feature     | `gitflow --json start feature <name>`      |
| Bugfix      | `gitflow --json start bugfix <name>`       |
| Hotfix      | `gitflow --json start hotfix <version>`    |
| Release     | `gitflow --json start release <version>`   |

### Skill Activation (Homologated)

- Use the gitflow skill before any code modifications.
- Always begin with `gitflow --json status`.
- Keep command selection aligned with task intent and branch type.

### LLM Activity Routing (Compact)

- discovery/state -> `gitflow --json status`
- branch divergence -> `gitflow --json backmerge`
- new work -> `gitflow --json start feature <name>`
- bug fix -> `gitflow --json start bugfix <name>`
- prod urgent fix -> `gitflow --json start hotfix <version>`
- release prep -> `gitflow --json start release <version>`
- branch sync/update -> `gitflow --json sync` / `gitflow --json pull`
- diagnostics -> `gitflow --json health` / `gitflow --json doctor`
- rollback last flow action -> `gitflow --json undo`
- close flow branch -> `gitflow --json finish`

### Full CLI

```
gitflow --json status|pull|init|sync|switch|backmerge|cleanup|health|doctor|log|undo|releasenotes|diagram|finish
gitflow --json start feature|bugfix|release|hotfix <name>
```

Exit codes: 0=success, 1=error, 2=conflict-needs-human


### When to use the gitflow skill

- Use the gitflow skill before any code modifications.
- Run `gitflow --json status` first and follow its branch/merge checks.
- Use `gitflow setup` after updating gitflow to refresh embedded skill content.

## Conventional Commits — Semantic Versioning

Always write commit messages in Conventional Commits format:
```
<type>(<scope>): <subject>
```

Types: `feat` (MINOR), `fix`/`perf` (PATCH), `feat!`/`fix!` (MAJOR), `chore`/`docs`/`refactor`/`test`/`ci`/`style` (no bump).
Breaking change: append `!` or add `BREAKING CHANGE:` footer.
Subject: imperative mood, no period, ≤72 chars.

## Session Completion Policy

When a coding session is complete and tests are passing:

1. Finish the active flow branch with `gitflow --json finish`.
2. If there are product changes intended for delivery, cut a release branch, run tests again, and finish the release.
3. Recreate the annotated tag with the GitHub noreply email if required by remote policy.
4. Push `main`, `develop`, and the release tag to origin.
5. Confirm the GitHub Actions release workflow is triggered.

Only skip release publication when the user explicitly asks not to publish.
