### Description
Yet Another Game/Engine. Not sure what I'll do with this one.
I think I'll start off with a simple model/material viewer and go from there.

### Todo
- Quaternions
- GLTF 2
- Procedural Skybox
- y-axis grid
- Deferred Renderer
- Skeletal Animations
- Gud Material System
- Cascaded Shadow Maps
- Order Independent Transparency
- Some Gui

### Building
Generally, you can:
```sh
jai -quiet build.jai
.build/game.exe
```

If you want to setup a simple and effective dev enviroment you can:
```
visit https://github.com/nvim-lua/kickstart.nvim and follow the instructions for your OS to install neovim + kickstart.nvim
Add this new keymap to your init.lua, the path to which you can find by typing :echo stdpath('config') inside neovim
vim.api.nvim_set_keymap('n', '<C-b>', ':w<CR>:!jai -quiet build.jai && cd .build && game && cd .. && echo "Press any key to continue..." && pause<CR>', { noremap = true, silent = true })
Now you can build while inside neovim by pressing CTRL+B and a terminal will spawn for the whole build/run for debug info
It just works.
```
