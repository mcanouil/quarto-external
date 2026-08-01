# Changelog

## Unreleased

### Bug Fixes

- fix: Read the `shift` alias for `shift-heading-level-by`. Quarto passes an empty value for an attribute the author did not write, and an empty value is truthy in Lua, so the alias was never reached and `shift=` silently did nothing.

### Documentation

- docs: Add a documentation website under `docs/`, built on the `atelier` project type and published to <https://m.canouil.dev/quarto-external/>.
- docs: Trim `README.md` to a landing page pointing at the website, and `example.qmd` to a short starting point to copy.
- docs: Add the Pages workflow, which renders `docs/` on pull requests and deploys it from the release tag.
- docs: Add the Quarto Extensions Updates workflow, scanning `docs` for the website's own dependencies.
- docs: Record that YAML front matter is stripped only when a `#<id>` fragment is used, and that a `.md` file has its shortcodes escaped while a `.qmd` file has them run.

## 1.7.0 (2026-05-31)

### New Features

- feat: Add line-range inclusion via `#L<start>-<end>` (or `#L<n>` for a single line).
- feat: Add `dedent` option that strips the common leading indent from every included code block.
- feat: Cache fetched files per render so repeated includes of the same URI hit the cache.

### Bug Fixes

- fix: Strip YAML frontmatter even when the closing `---` has no trailing newline.
- fix: Escape every `{{< ... >}}` shortcode in non-Quarto markdown sources, including nested shortcodes (previously the greedy regex broke when a shortcode body contained another shortcode).
- fix: Warn when `shift-heading-level-by` is outside `[-5, 5]` instead of silently capping headings or demoting them to bold paragraphs, and truncate non-integer values explicitly rather than relying on `tonumber`'s float coercion.

### Refactoring

- refactor: Synchronise shared modules (`content-extraction.lua`, `html.lua`, `logging.lua`, `string.lua`, `validation.lua`) with canonical versions.

## 1.6.1 (2026-04-15)

### Refactoring

- refactor: Synchronise shared modules (`logging.lua`, `string.lua`, `validation.lua`) with canonical versions.

## 1.6.0 (2026-03-23)

### Refactoring

- refactor: Replace monolithic `utils.lua` with focused modules (`string.lua`, `logging.lua`, `metadata.lua`, `pandoc-helpers.lua`, `html.lua`, `paths.lua`, `colour.lua`).

## 1.5.0 (2026-02-21)

### New Features

- feat: Add extension-provided code snippets (#28).
- feat: Add _schema.yml for configuration validation and IDE support (#24).

### Bug Fixes

- fix: Remove version suffix from raw GitHub URLs in example.
- fix: Add file completion hint to file shortcode argument (#25).

## 1.4.1 (2026-02-11)

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
