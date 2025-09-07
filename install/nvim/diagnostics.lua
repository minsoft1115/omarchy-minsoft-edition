return {
  {
    "neovim/nvim-lspconfig", -- 플러그인 이름 필수
    config = function()
      vim.diagnostic.config({
        virtual_text = { current_line = true },
        virtual_lines = { current_line = true },
        signs = false,
        underline = true,
      })
    end,
  },
}
