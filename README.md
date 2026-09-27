# flat.nvim

A lightweight, high-speed structured plain-text editor integration for Neovim.

`flat.nvim` turns plain text files into structured data effortlessly without leaving your editor. Designed for quick note-taking, task tracking, walkthroughs, and dev logs, it offers structured referencing, linting, formatting, and navigation capabilities.

<img width="777" height="553" alt="image" src="https://github.com/user-attachments/assets/45af44c9-1eca-4151-8598-d6b47895b3b2" />

---

## ✨ Features

- **High-Performance Parsing**: Fast top-to-bottom single-pass parsing engine with nested constant resolution.
- **Syntax Highlighting**: Theme-aware highlighting using Neovim Extmarks.
- **Smart Completion**: Auto-completion for sections, constants, and enums via `nvim-cmp` or `omnifunc`.
- **Diagnostics & Linter**: Real-time syntax checking, duplicate identifier validation, and memory-safe reference checking.
- **Code Navigation**: Jump to definitions, search references across files, and rename symbols globally.
- **Auto Formatting**: Native formatting support (built-in integration with `conform.nvim`).

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

- **Constant Reference**: `#$ConstName;` (e.g., `#$Domain;/api`)
- **Enum Value Reference**: `#$EnumName:Value;` (e.g., `#$Status:Done;`)
- **Inline Decoration**: `#*Highlight Text;`### Escape Character

Prefix special tokens (`#`, `;`, `\`) with a backslash (`\`) to escape them.

- Example: `\#*Not Inline directive\;` -> Renders as plain text.

---

## 🧭 Navigation Keymaps

`flat.nvim` provides LSP-like navigation features out of the box for `.flt` files.

| Keymap       | Action           | Description                                                           |
| ------------ | ---------------- | --------------------------------------------------------------------- |
| `gd`         | Go to Definition | Jump to declaration in the current buffer or imported files           |
| `gr`         | Find References  | Find all symbol occurrences across files via Quickfix list            |
| `<leader>rn` | Rename Symbol    | Safely rename declarations and reference usages across imported files |

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

---

## 🚀 Roadmap

- [x] High-performance Lua parser & syntax highlighting
- [x] Diagnostics, Completion & Code Navigation (`gd`, `gr`, `<leader>rn`)
- [ ] Native data conversion support (e.g., Lua table / JSON export)
- [ ] Tree-sitter parser implementation
