-- Instala (headless) todos os servidores LSP e ferramentas que o LazyVim + extras pedem.
-- O mason-lspconfig pula essa instalação em modo headless, por isso o install.sh usa este script.
-- uso: nvim --headless -c "luafile scripts/nvim-mason-install.lua"

-- carrega a config do LSP do LazyVim (normalmente só acontece ao abrir um arquivo)
require("lazy").load({ plugins = { "nvim-lspconfig", "mason.nvim" } })

local registry = require("mason-registry")
local lsp_to_pkg = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package

local wanted = {}
for _, server in ipairs(require("mason-lspconfig.settings").current.ensure_installed or {}) do
  wanted[lsp_to_pkg[server] or server] = true
end
for _, tool in ipairs(LazyVim.opts("mason.nvim").ensure_installed or {}) do
  wanted[tool] = true
end

local pending = 0
local queued = false
local failed = {}
registry.refresh(function()
  for name in pairs(wanted) do
    local ok, pkg = pcall(registry.get_package, name)
    if not ok then
      table.insert(failed, name .. " (não existe no mason)")
    elseif not pkg:is_installed() then
      pending = pending + 1
      io.stdout:write("  instalando " .. name .. "\n")
      pkg:install():once("closed", function()
        pending = pending - 1
        if not pkg:is_installed() then
          table.insert(failed, name)
        end
      end)
    end
  end
  queued = true
end)

vim.wait(20 * 60 * 1000, function() return queued and pending == 0 end, 500)

if #failed > 0 then
  io.stdout:write("  falhou: " .. table.concat(failed, ", ") .. "\n")
  vim.cmd("cq")
end
vim.cmd("qa!")
