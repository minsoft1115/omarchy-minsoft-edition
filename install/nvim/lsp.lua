-- lua/plugins/lsp.lua
return {
	-- LSP 본체 설정
	{
		"neovim/nvim-lspconfig",
		opts = function(_, opts)
			local lspconfig = require("lspconfig")
			local util = require("lspconfig.util")

			-- 기존 opts.servers 유지
			opts.servers = opts.servers or {}

			-- dotnet tool 설치된 csharp-ls 사용
			-- PATH가 이미 잡혀 있다면 cmd는 { "csharp-ls" } 로 충분
			-- PATH가 불안정하면 절대 경로를 명시 (예: "/home/USER/.dotnet/tools/csharp-ls")
			opts.servers.csharp_ls = {
				cmd = { "csharp-ls" }, -- 필요 시 절대 경로로 교체
				filetypes = { "cs" },

				-- .sln 우선 → .csproj → .git 순으로 루트 탐지 (다중 프로젝트에서 안정적)
				root_dir = function(fname)
					return util.root_pattern("*.sln")(fname)
						or util.root_pattern("*.csproj")(fname)
						or util.root_pattern(".git")(fname)
						or util.find_git_ancestor(fname)
						or util.path.dirname(fname)
				end,

				-- 선택적 설정
				settings = {
					csharp = {
						-- 특정 솔루션을 강제로 고정하고 싶을 때 사용
						-- solution = "/absolute/path/Your.sln",
						applyFormattingOptions = false,
					},
				},
			}
		end,
	},

	-- Mason을 쓰더라도, dotnet tool로 설치한 경우 자동 설치는 끄는 편이 명확
	{
		"williamboman/mason-lspconfig.nvim",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			-- dotnet tool 버전을 사용할 것이므로 mason이 csharp_ls를 설치/관리하지 않게 둠
			-- mason을 병행 관리하고 싶다면 주석 해제:
			-- table.insert(opts.ensure_installed, "csharp_ls")
		end,
	},
}
