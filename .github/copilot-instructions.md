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
