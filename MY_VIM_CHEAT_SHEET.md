# My Vim Cheat Sheet

Space is leader. Tap it and wait: which-key lists every shortcut.

## Layout (the VS Code stuff)

- `ctrl+h/j/k/l` — move between tree, editor, terminal
- `ctrl+e` — open/close file tree
- `ctrl+shift+j` — open terminal panel; again (inside it) hides it
- `ctrl+shift+k` — terminal → editor, panel stays open
- `ctrl+shift+n` / `ctrl+shift+w` / `ctrl+o` — new / close / next terminal (in terminal)
- `Esc Esc` — terminal into normal mode (scroll, copy output)
- `ctrl+shift+g` — git changes + diffs; again to close
- `alt+h/l` — move the nearest vertical divider left / right (works in terminal)
- `alt+k/j` — move the nearest horizontal divider up / down; `alt+k` in terminal = taller
- `ctrl+w =` — make all windows equal; or drag dividers with mouse

## Find things (cmd+p, cmd+shift+f)

- `Space s f` — find file by name
- `Space s g` — search text in project
- `Space s w` — search word under cursor
- `Space s .` — recent files
- `Space Space` — switch open files
- `Space /` — search in this file
- `Space s r` — reopen last search
- `/text` then `n` / `N` — search in file, next / previous
- Searches include dotfiles and `.idea`, skip `node_modules` and `.git`

## Replace (cmd+shift+h)

- `Space S` — replace across project; `Space r` in the panel applies
- `v` select, then `Space S` — prefill with selection
- `Space R` — replace in this file (panel)
- `:%s/old/new/gc` — replace in file, confirm each (drop `c` for all)
- `*` then `:%s//new/g` — replace word under cursor everywhere in file
- `Space r n` — rename symbol across project (F2)

## Code (F12, hover, quick fix)

- `gd` — go to definition; `ctrl+o` jumps back
- `gr` — references
- `gI` — implementation
- `K` — hover: type, docs, signature (no mouse hover; cursor on it)
- `K` again — jump into the popup to scroll; `q` closes, moving closes too
- `ctrl+s` — parameter hints while typing a call (insert mode)
- `Space c a` — code action / quick fix
- `Space e` — show error under cursor
- `]d` / `[d` — next / previous error
- `Space s d` — all errors in project

## File tree

- `Enter` — open file / expand folder
- `n` / `d` — new file / new folder (type path, `Enter`)
- `r` — rename (updates imports)
- `m` — move
- `D` — delete
- `c` / `x` / `p` — copy / cut / paste file
- `H` — hide / show hidden files (shown by default)
- `?` — all tree keys

## Git

- `ctrl+shift+g` — changes view: file list + full-file side-by-side diff; again to close
- `Enter` — open a file's diff (in the file list)
- `Space b` — hide / show the file list
- `]c` / `[c` — next / previous change; `]f` / `[f` — next / previous file
- `-` — stage / unstage file; `S` / `U` — stage all / unstage all
- `Space h s` / `Space h r` — stage / discard the change under cursor
- `X` — discard all changes to a file (in the file list)
- `cc` — commit staged (in the file list)
- `t` — toggle side-by-side / inline; `g?` — every key in this view
- `Space g s` — fugitive status (`=` inline diff, `s` stage)
- `:Git push` / `:Git pull`

## Mouse habits → keys

- Click a line → `42G` or `:42`, or just click (mouse works)
- Scroll → `ctrl+d` / `ctrl+u` half page
- Go back after jump (alt+←) → `ctrl+o`; forward → `ctrl+i`
- Top / bottom of file → `gg` / `G`
- Select → `v` chars, `V` lines, `ctrl+v` block
- Select all → `ggVG`
- Copy / paste → `y` / `p` (system clipboard)
- Copy line / cut line → `yy` / `dd`
- Paste over selection, keep clipboard → `Space p`
- Undo / redo → `u` / `ctrl+r`
- Move lines (alt+↑↓) → `V` select, `J` / `K`
- Indent → `>` / `<` in visual, `>>` / `<<` in normal
- Comment → `gcc` line, `gc` selection
- Multi-cursor → `*` then `cgn`, type, `Esc`, `.` repeats
- Edit many lines at once → `ctrl+v`, select column, `I` type, `Esc`
- Change inside quotes / parens → `ci"` / `ci(`
- Wrap in quotes → `sa` + motion + `"` (e.g. `saiw"`)
- Fold (cmd+k 0) → `za` toggle, `zc` close, `zo` open, `zR` open all

## Markdown

- Renders formatted automatically; raw while typing in insert mode
- `Space m` — toggle formatted / raw

## Files & windows

- Save → `:w`; save all → `:wa`
- Close file → `:bd`; quit → `:q`; quit all → `:qa`
- Split right / below → `:vsp` / `:sp`
- Close split → `ctrl+w q`
- Old file browser → `Space p v`

## Stuck?

- Weird mode → `Esc` (twice in terminal)
- Can't type → you're in normal mode, press `i`
- Find any key → `Space s k`
- Help on anything → `Space s h`
