# Neovim config

A VS Code style Neovim for Ghostty: file tree, editor, a terminal panel that stays at the bottom, and codediff.nvim as the git view.

## Workflow

- While this config is on trial it runs as `NVIM_APPNAME=nvim-ide` (the `nvim` alias), from `~/.config/nvim-ide`. Make each change there, then copy it into this repo. Keep the two trees identical: `diff -rq ~/.config/nvim-ide ~/.config/nvim -x .git -x lazy-lock.json` prints nothing.
- Commit every change, one commit per feature or fix, with a message that describes what the user now sees. Push the branch after each commit so regressions can be audited and bisected later. Ask before merging into `main` or force pushing.
- When a key or a behavior changes, update `MY_VIM_CHEAT_SHEET.md` in the same commit.
- No code comments. Lint directives such as `---@diagnostic` are the only exception.

## Testing

- Logic and layout: `NVIM_APPNAME=nvim-ide nvim --headless`, with a script that drives the config and prints the result.
- Anything involving modes or keys needs a real UI: run nvim in a pty with `--listen`, send keys with `nvim --server <sock> --remote-send`, and read state with `--remote-expr`. Headless mode reports modes unreliably.
- Use scratch git repos for tests, never a real project.

## Traps already hit

- `<C-i>` and `<Tab>` are the same key to Neovim in every encoding. A terminal-mode `<C-i>` mapping breaks shell completion.
- toggleterm queues `startinsert` and `stopinsert` with `vim.schedule`. Code that moves focus after opening or closing a terminal must schedule its own mode change after those, or insert mode leaks into another window.
- A window remembers its options per buffer. A file first shown in a plugin window (codediff panes, the graph) brings that window's `nonumber` and similar options back into the editor; `init.lua` resets them on `BufWinEnter`.
- In a terminal's normal mode, Vim's own `<C-o>` jump list replaces the terminal with another buffer. Terminal buffers map `<C-o>` locally to switch terminals instead.
