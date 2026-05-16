---@diagnostic disable: need-check-nil
local h = require("tests.helpers")
local validate = require("namu.validate")
---@diagnostic disable-next-line: undefined-global
local new_set = MiniTest.new_set

local T = new_set()

T["Validate.auto_start"] = new_set()

T["Validate.auto_start"]["accepts valid auto_start configuration"] = function()
  local ok, issues = validate.validate_picker_options({
    auto_start = {
      enabled = true,
      mode = "treesitter",
    },
  })

  h.eq(ok, true)
  h.eq(#issues, 0)
end

T["Validate.auto_start"]["rejects invalid auto_start mode"] = function()
  local ok, issues = validate.validate_picker_options({
    auto_start = {
      enabled = true,
      mode = "workspace",
    },
  })

  h.eq(ok, false)
  h.eq(issues[1].msg, "auto_start.mode must be either 'lsp' or 'treesitter'")
end

return T
