# flat.nvim

A lightweight, high-speed structured plain-text editor integration for Neovim.

`flat.nvim` turns plain text files into structured data effortlessly without leaving your editor. Designed for quick note-taking, task tracking, walkthroughs, and dev logs, it offers structured referencing, linting, formatting, and export capabilities.

---

## ✨ Features

- **High-Performance Parsing**: Fast top-to-bottom single-pass parsing engine with nested constant resolution.
- **Syntax Highlighting**: Theme-aware highlighting using Neovim Extmarks.
- **Smart Completion**: Auto-completion for sections, constants, and enums via `nvim-cmp` or `omnifunc`.
- **Diagnostics & Linter**: Real-time syntax checking, duplicate identifier validation, and memory-safe reference checking.
- **Auto Formatting**: Native formatting support (built-in integration with `conform.nvim`).
- **Data Export**: Convert `.flt` documents to JSON or SQL directly within Neovim.

---

## 📦 Installation

Install `flat.nvim` using your favorite plugin manager.

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  {
    "nanefin/flat.nvim",
    ft = { "flat" },
    opts = {},
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        flat = { "flat_formatter" },
      },
    },
  },
}
```

---

## 📝 Syntax Overview

Flat syntax is simple and line-oriented.

### Directives

| Syntax               | Description                                           | Example                              |
| -------------------- | ----------------------------------------------------- | ------------------------------------ |
| `#!sec:Name`         | Defines a new section header                          | `#!sec:Overview`                     |
| `#!const:Name:Value` | Defines a constant (supports top-down nested refs)    | `#!const:Domain:https://example.com` |
| `#!enum:Name{A,B}`   | Defines an Enum and its valid values                  | `#!enum:Status{Todo, Doing, Done}`   |
| `#!import:path`      | Imports sections, consts, and enums from another file | `#!import: ./common.flt`             |
| `#!empty`            | Explicitly marks an empty data line                   | `#!empty`                            |
| `##`                 | Line comment                                          | `## This is a comment`               |

> **Note**: Identifier names (sections, constants, and enums) must be unique across the document. Duplicates are disallowed and flagged by the linter.

### Inline References

Inline references are enclosed between the reference token and a terminating semicolon `;`.

- **Section Reference**: `#$SectionName;`
- **Constant Reference**: `#$ConstName;` (e.g., `#$Domain;/api`)
- **Enum Value Reference**: `#$EnumName:Value;` (e.g., `#$Status:Done;`)
- **Inline Decoration**: `#*Highlight Text;`

### Escape Character

Prefix special tokens (`#`, `;`, `\`) with a backslash (`\`) to escape them.

- Example: `\#*Not Inline directive\;` -> Renders as plain text.

---

## ⚡ Commands

| Command       | Description                                                             |
| ------------- | ----------------------------------------------------------------------- |
| `:FlatToJSON` | Converts the current `.flt` buffer to JSON and opens it in a new buffer |
| `:FlatToSQL`  | Converts the current `.flt` buffer to SQL and opens it in a new buffer  |

---

## ⚙️ Configuration

Default configuration options:

```lua
require("flat").setup({
  highlight = true,   -- Enable custom Extmark syntax highlighting
  linter = true,      -- Enable real-time diagnostics and reference checking
  completion = true,  -- Enable nvim-cmp / omnifunc completion
})
```
