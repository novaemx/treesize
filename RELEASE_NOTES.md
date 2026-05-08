# Release 0.1.2

**Date:** 2026-05-08

## What's New

- Merge feature 'fix-ci-cgo-crosscompile' into develop
- Merge feature 'smart-release-tag' into develop
- Smart release-tag handles existing tags gracefully
- Merge feature 'fix-ci-env-tap-token' into develop
- Merge feature 'fix-ci-tap-token' into develop

## Bug Fixes

- Set CC arch flags for CGO cross-compile on ARM64 runner, pin action versions
- Expose TAP_TOKEN as env var for step-level if conditions
- Make homebrew-tap steps conditional on TAP_TOKEN secret

