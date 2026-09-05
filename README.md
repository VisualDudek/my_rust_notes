# My Book

[![Deploy mdBook](https://github.com/VisualDudek/my_rust_notes/actions/workflows/mdbook.yml/badge.svg)](https://github.com/VisualDudek/my_rust_notes/actions/workflows/mdbook.yml)
[![GitHub Pages](https://img.shields.io/badge/docs-live-blue)](https://VisualDudek.github.io/my_rust_notes/)

# my_rust_notes
Rust notes and learning mdBook framework

- [getting started](./src/mdbook-getting-started.md)

## VS Code snippet

Here's a VS Code snippet for that. Add it to your Markdown snippets file (Command Palette → "Snippets: Configure User Snippets" → "markdown.json"):

```json
{
  "Details Block": {
    "prefix": "details",
    "body": [
      "<br>",
      "<details>",
      "<summary>${1:Show final thoughts}</summary>",
      "",
      "${2:placeholder}",
      "",
      "</details>",
      "<br>",
      "$0"
    ],
    "description": "Insert a collapsible <details> block"
  }
}
```

WARNING! Need to manually trigger after typing the prefix and hitting Ctrl+space

Notes:

- `$1` and `$2` are tab-stops — after typing `details` and hitting Tab/Enter to expand, your cursor lands on `Show final thoughts` (editable inline, pre-filled), Tab again to jump to `placeholder`, and `$0` marks where the cursor ends up after you're done.
- If you want it scoped to Markdown only (not any file type), make sure this lives in `markdown.json` specifically rather than global snippets — that's what the language-specific snippet file does automatically.
- If you'd rather trigger it with something less likely to collide with normal text (like typing the word "details" mid-sentence), consider a prefix like `!details` or `xdetails` instead.

One gotcha: VS Code's snippet body is a JSON string array joined by `\n`, so the blank lines between `<summary>` and the placeholder, and between the placeholder and `</details>`, are preserved exactly as empty strings in the array — that's what keeps the visual spacing matching your original block.