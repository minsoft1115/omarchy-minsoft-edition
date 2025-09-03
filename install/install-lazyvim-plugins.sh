dotnet tool install --global csharp-ls

cp ./nvim/scrollbar.lua $HOME/.config/nvim/lua/plugins/
cp ./nvim/lsp.lua $HOME/.config/nvim/lua/plugins/

mv $HOME/.config/nvim/lua/plugins/snacks-animated-scrolling-off.lua $HOME/.config/nvim/lua/plugins/snacks-animated-scrolling-off.lua.bak
