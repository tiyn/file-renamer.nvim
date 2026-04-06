# file-renamer.nvim

Rename files like text inside NeoVIM.

This plugin lets you edit filenames directly in a buffer and apply the changes to the file system.

This plugin is inspired by and based on the functionality of
[qpkorrs vim-renamer](https://github.com/qpkorr/vim-renamer) though it does not share any code with
it.


## Features

- Edit filenames in a buffer
- Navigate directories (press `<CR>` on directory)
- Support for nested renaming (for `file -> dir/file` a directory is created if it doesn't exist
    already)
- Safe renaming and directory creation (handles `a <-> b` and `a -> a/a`)
- Skips invalid or conflicting renames (prohibits collision of file and directory names)

## Installation (lazy.nvim)

```lua
return {
  "tiyn/file-renamer.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "Ren", "Renamer" },
}
````

## Usage

First start the renaming buffer with the following command.

```vim
:Rename
```

Change the files as needed.
Then apply the changes using the following command.

```vim
:Ren
```

## Notes

* Do not change the number of lines
* Lines starting with `#` are ignored
