# External Extension for Quarto

This repository provides an extension for Quarto that allows you to include content from external sources or files into your Quarto documents.

## Installation

```bash
quarto add mcanouil/quarto-external
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Usage

To use the external extension, you can include external content or a section from a file into your Quarto document using the `external` shortcode.

```{.markdown shortcodes=false}
{{< external <URL>#<section-id> >}}
```

> [!IMPORTANT]
> The `external` shortcode should be on its own line, without any other content on the same line.
> An empty line before and after the shortcode is required for better readability.

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).

Outputs of `example.qmd`:

- [HTML](https://m.canouil.dev/quarto-external/)
