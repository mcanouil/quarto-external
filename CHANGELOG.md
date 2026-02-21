# Changelog

## Unreleased

No user-facing changes.

## 1.5.0 (2026-02-21)

### New Features

- feat: Add extension-provided code snippets (#28).
- feat: Add _schema.yml for configuration validation and IDE support (#24).

### Bug Fixes

- fix: Remove version suffix from raw GitHub URLs in example.
- fix: Add file completion hint to file shortcode argument (#25).

## 1.4.1 (2026-02-11)

No user-facing changes.

## 1.4.0 (2026-01-27)

### New Features

- feat: Add heading level shifting functionality (#21).

### Bug Fixes

- fix: Update copyright year.
- fix: Use british english spelling.

### Style

- style: Reformat file.

## 1.3.0 (2025-11-23)

### New Features

- feat: Allow inclusion of a div by its ID (#19).

## 1.2.0 (2025-10-25)

### New Features

- feat: Add author information and table of contents to example.qmd.
- feat: Refactor and enhance logging and configuration handling (#17).

### Documentation

- docs: Add output section for example.qmd in README.
- docs: Enhance documentation.
- docs: Update README.md.

## 1.1.1 (2025-10-17)

### Bug Fixes

- fix: Refine regex for escape all shortcodes in markdown files (#15).

## 1.1.0 (2025-10-16)

### New Features

- feat: Treat "qmd" and "md" files differently (#13).

### Bug Fixes

- fix: Improve regex for external shortcode matching/escaping.
- fix: Escape external shortcode in included files.

### Documentation

- docs: Add disclaimer about non self-contained projects.
- docs: Add that only markdown-based documents are allowed.

## 1.0.0 (2025-07-28)

### Bug Fixes

- fix: Minor text changes.
- fix: Luadoc and rename variable.
- fix: Return pandoc.Blocks when filtering.

### Refactoring

- refactor: Use `quarto.utils.string_to_blocks` to handle Quarto's markdown.

### Documentation

- docs: Use several external shortcodes as example.
- docs: Change language and add note.
- docs: Make readme more compatible with Quarto.

## 0.1.1 (2025-07-26)

### New Features

- feat: Add markdown file check.

### Documentation

- docs: Show raw shortcode.

## 0.1.0 (2025-07-25)

### New Features

- feat: Initial commit.
