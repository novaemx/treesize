# Changelog

All notable changes to this project will be documented in this file.

This project follows Semantic Versioning and uses a Keep a Changelog style.

## [Unreleased]

### TLDR

- Placeholder for upcoming release summary.

### Detailed

#### Added

- Placeholder.

## [0.1.10] - 2026-05-08

### TLDR

- Enforced release policy requiring TLDR + Detailed changelog sections.
- GitHub Release description is now generated from CHANGELOG TLDR.
- Release notes now always point readers to CHANGELOG.md for full details.

### Detailed

#### Added

- Added canonical CHANGELOG.md with Keep a Changelog structure and SemVer references.
- Added explicit changelog governance rules to Copilot instructions.

#### Changed

- Release workflow now extracts the matching version section and TLDR from CHANGELOG.md.
- GitHub Release notes now include TLDR summary plus explicit reference to detailed changes in CHANGELOG.md.

## [0.1.9] - 2026-05-08

### TLDR

- Live scan now updates the UI incrementally while scanning.
- macOS UI was polished with native menu/About and visual effects.
- Release workflow now supports reruns and stable publishing behavior.

### Detailed

#### Added

- Streaming scan mode via scan-json-stream for progressive UI updates.
- About menu entry in the native app menu.
- Changelog/release policy requiring TLDR + Detailed per release.

#### Changed

- Refined native macOS chrome with visual effect header/footer and SF Symbol toolbar buttons.
- Updated release workflow to generate tag description content from changelog TLDR.

#### Fixed

- Release rerun behavior now updates existing release notes and re-uploads assets safely.

[Unreleased]: https://github.com/novaemx/treesize/compare/v0.1.10...HEAD
[0.1.10]: https://github.com/novaemx/treesize/releases/tag/v0.1.10
[0.1.9]: https://github.com/novaemx/treesize/releases/tag/v0.1.9
