# Changelog

All notable changes to this project will be documented in this file.

This project follows Semantic Versioning and uses a Keep a Changelog style.

## [Unreleased]

### TLDR

- Placeholder for upcoming release summary.

### Detailed

#### Added

- Placeholder.

## [0.1.14] - 2026-05-08

### TLDR

- Fixed Darwin linker failure by linking QuartzCore in cgo for the custom gradient UI.
- Release pipeline should now build universal macOS binaries successfully.

### Detailed

#### Fixed

- Added `-framework QuartzCore` to darwin cgo linker flags in the App bridge package.
- Resolved `Undefined symbols for architecture x86_64: _OBJC_CLASS_$_CAGradientLayer` during universal build.

## [0.1.13] - 2026-05-08

### TLDR

- Fixed the remaining macOS CI build failure by removing readonly `NSView.tag` assignments from custom table cells.
- Darwin release pipeline should now compile the bridge cleanly in GitHub Actions.

### Detailed

#### Fixed

- Replaced `NSView.tag` usage in custom AppKit cell subviews with identifier-based lookup helpers.
- Eliminated the readonly-property assignments that still failed under the macOS CI compiler.
- Kept the custom Name and percentage bar rendering without relying on unsupported view tagging patterns.

## [0.1.12] - 2026-05-08

### TLDR

- Fixed the macOS build failure caused by custom NSTableCellView wiring and gradient-layer rendering.
- Release now compiles again on GitHub Actions for Darwin.

### Detailed

#### Fixed

- Replaced readonly NSTableCellView property assignments with tag-based view lookup in custom cells.
- Added QuartzCore import and valid gradient layer setup for the percentage bar column.
- Corrected custom cell rendering so the AppKit bridge builds cleanly under the macOS CI toolchain.

## [0.1.11] - 2026-05-08

### TLDR

- Tree now updates live while scanning and can be stopped immediately with partial results kept.
- macOS UI now includes richer TreeSize-style columns and visual bars for size distribution.
- App now warns when protected folders were skipped and guides users to Full Disk Access for more exact totals.

### Detailed

#### Added

- Added cancellable streaming scan pipeline from Go to the native macOS UI.
- Added Stop Scan action in the toolbar and File menu.
- Added percentage gradient bar rendering and semi-transparent size bar rendering in the Name column.
- Added Full Disk Access prompt when protected folders are skipped.

#### Changed

- Updated the table to include Allocated alongside Size, Files, Folders, percentage, and Last Modified.
- Improved progressive sorting so larger directories float to the top while results arrive.
- Reduced metadata overhead by using progressive scanner snapshots and lighter entry inspection paths.

#### Fixed

- Partial scan results now remain visible when a running scan is stopped.

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

[Unreleased]: https://github.com/novaemx/treesize/compare/v0.1.14...HEAD
[0.1.14]: https://github.com/novaemx/treesize/releases/tag/v0.1.14
[0.1.13]: https://github.com/novaemx/treesize/releases/tag/v0.1.13
[0.1.12]: https://github.com/novaemx/treesize/releases/tag/v0.1.12
[0.1.11]: https://github.com/novaemx/treesize/releases/tag/v0.1.11
[0.1.10]: https://github.com/novaemx/treesize/releases/tag/v0.1.10
[0.1.9]: https://github.com/novaemx/treesize/releases/tag/v0.1.9
