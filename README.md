# External Extension for Quarto

`external` is an extension for Quarto that provides a shortcode to include markdown from another file or a URL, whole or by section, div, or line range.

## Installation

```bash
quarto add mcanouil/quarto-external@1.7.0
```

This will install the extension under the `_extensions` subdirectory.

If you're using version control, you will want to check in this directory.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-external/>: every fragment form, heading shifting, dedenting, and the validation rules.

[`example.qmd`](example.qmd) is a short, standalone starting point you can copy.

> [!NOTE]
> Using external content breaks the fully reproducible and self-contained nature of Quarto projects, as documents become dependent on external sources that may change or become unavailable.

## Licence

[MIT](https://github.com/mcanouil/quarto-external?tab=MIT-1-ov-file#readme).
