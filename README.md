# External Extension for Quarto

This repository provides an extension for Quarto that allows you to include content from external sources or files into your Quarto documents.

## Installation

```bash
quarto add mcanouil/quarto-external@1.5.0
```

This will install the extension under the `_extensions` subdirectory.

If you're using version control, you will want to check in this directory.

## Usage

To use the external extension, you can include external content, a specific section, or a div from a file into your Quarto document using the `external` shortcode.

### Basic syntax

Include the entire file:

```markdown
{{< external <URI> >}}
```

Include a specific section (by header ID):

```markdown
{{< external <URI>#<section-id> >}}
```

Include a specific div (by div ID):

```markdown
{{< external <URI>#<div-id> >}}
```

`<URI>` specifies the location of the external file.
This can be a local file path (outside the project directory) or a URL.

When using `#<id>`, the extension will first look for a header with that ID.
If no header is found, it will then search for a div with that ID.

> [!IMPORTANT]
> The `external` shortcode must be placed on its own line with no other content.
> Include blank lines both before and after the shortcode.
>
> No code cells will or can be executed from the included file.
>
> Currently supports `.md`, `.markdown`, and `.qmd` files only.
>
> - `.md` and `.markdown` files are included as-is.
> - `.qmd` files are processed as Quarto documents, so you can use Quarto features like citations, cross-references, and math.
>
> **Note:** Using external content breaks the fully reproducible and self-contained nature of Quarto projects, as documents become dependent on external sources that may change or become unavailable.

### Shifting heading levels

You can adjust the heading levels of included content using the `shift-heading-level-by` parameter (or the shorter `shift` alias):

```markdown
{{< external <URI> shift-heading-level-by=1 >}}
{{< external <URI>#<section-id> shift=1 >}}
```

- **Positive values** demote headings: `shift=1` turns h1 into h2, h2 into h3, etc.
- **Negative values** promote headings: `shift=-1` turns h2 into h1, h3 into h2, etc.
- Headings that would become level 0 or lower are converted to bold paragraphs.
- Headings cannot exceed level 6 (capped).

This is useful when including content from a standalone document (with its own h1) into a section of your document.

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).

Output of `example.qmd`:

- [HTML](https://m.canouil.dev/quarto-external/)
