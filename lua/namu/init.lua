local M = {}

-- Helper function to check if a module should be enabled
local function is_module_enabled(module_name)
  local config_manager = require("namu.core.config_manager")
  if config_manager.user_config[module_name] and config_manager.user_config[module_name].enable ~= nil then
    return config_manager.user_config[module_name].enable
  end
  return true
end

-- Default configuration
M.config = {
  namu_symbols = { enable = true, options = {} },
  namu_ctags = { enable = false, options = {} },
  selecta = { enable = true, options = {} },
  callhierarchy = { enable = true, options = {} },
  workspace = { enable = true, options = {} },
  diagnostics = { enable = true, options = {} },
  watchtower = { enable = true, options = {} },
  colorscheme = { enable = false, options = {} },
  ui_select = { enable = false, options = {} },
}

local auto_start_augroup = nil

local function setup_auto_start()
  local config_manager = require("namu.core.config_manager")
  local sidebar_manager = require("namu.core.sidebar_manager")
  local symbol_config = config_manager.get_config("namu_symbols")
  local auto_start = symbol_config.auto_start or {}

  if auto_start_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, auto_start_augroup)
    auto_start_augroup = nil
  end

  if not auto_start.enabled or not is_module_enabled("namu_symbols") then
    return
  end

  local function launch()
    if sidebar_manager.has_primary() or sidebar_manager.is_restoring() then
      return
    end

    if auto_start.mode == "treesitter" then
      require("namu.namu_symbols").show_treesitter()
    else
      require("namu.namu_symbols").show()
    end
  end

  if vim.v.vim_did_enter == 1 then
    vim.schedule(launch)
    return
  end

  auto_start_augroup = vim.api.nvim_create_augroup("NamuAutoStart", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = auto_start_augroup,
    once = true,
    callback = function()
      vim.schedule(launch)
    end,
  })
end

M.setup = function(opts)
  opts = opts or {}
  -- Merge the top-level config
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Setup the config manager with user configuration
  local config_manager = require("namu.core.config_manager")
  config_manager.setup(M.config)

  -- Defer highlights setup to avoid blocking main initialization
  vim.schedule(function()
    require("namu.core.highlights").setup()
  end)

  if is_module_enabled("namu_symbols") then
    local symbol_config = config_manager.get_config("namu_symbols")
    require("namu.selecta").setup(symbol_config)
    require("namu.namu_symbols").setup() -- No options, will use config manager
  end

  if is_module_enabled("namu_ctags") then
    local ctags_config = config_manager.get_config("namu_ctags")
    require("namu.namu_ctags").setup(ctags_config)
  end

  if is_module_enabled("callhierarchy") then
    local callhierarchy_config = config_manager.get_config("callhierarchy")
    require("namu.namu_callhierarchy").setup(callhierarchy_config)
  end

  if is_module_enabled("workspace") then
    local workspace_config = config_manager.get_config("workspace")
    require("namu.namu_workspace").setup(workspace_config)
  end

  if is_module_enabled("watchtower") then
    local watchtower_config = config_manager.get_config("watchtower")
    require("namu.namu_watchtower").setup(watchtower_config)
  end

  if is_module_enabled("diagnostics") then
    local diagnostics_config = config_manager.get_config("diagnostics")
    require("namu.namu_diagnostics").setup(diagnostics_config)
  end

  if is_module_enabled("colorscheme") then
    local colorscheme_config = config_manager.get_config("colorscheme")
    require("namu.colorscheme").setup(colorscheme_config)
  end

  if is_module_enabled("ui_select") then
    local ui_select_config = config_manager.get_config("ui_select")
    require("namu.ui_select").setup(ui_select_config)
  end

  setup_auto_start()
end

return M
