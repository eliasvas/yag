### Description
My attempt at making (yet-another) Game/Engine in Jai.</br>
I want to keep things minimal, to be able to move around the codebase easily.</br>
I'll try to make an actual game this time, I promise!</br>

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

-- init.lua
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smarttab = true

...

vim.api.nvim_set_keymap('n', '<C-b>', ':w<CR>:!jai -quiet build.jai && cd .build && game && cd .. && echo "Press any key to continue..." && pause<CR>', { noremap = true, silent = true })

Now you can build while inside neovim by pressing CTRL+B and a terminal will spawn for the whole build/run for debug info
It just works.
```

### Favourite Resources:
[LearnOpenGL](https://learnopengl.com/) - to understand/implement the 'modern' rendering pipeline  </br>
[glTF-Sample-Models](https://github.com/KhronosGroup/glTF-Sample-Models) - model collection to test out the glTF parser</br>
[Ryan's UI Series](https://www.rfleury.com/p/ui-series-table-of-contents) - great UI articles, helped me a ton</br>
[Ryan's Arena Article](https://www.rfleury.com/p/untangling-lifetimes-the-arena-allocator) opened my eyes to manual memory management</br>
[Cherno Asset System](https://www.youtube.com/watch?v=9oDIdb8RLh0) good intro to asset systems</br>
