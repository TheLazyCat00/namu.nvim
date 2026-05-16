---@diagnostic disable: need-check-nil, param-type-mismatch
local h = require("tests.helpers")
local symbol_utils = require("namu.core.symbol_utils")
---@diagnostic disable-next-line: undefined-global
local new_set = MiniTest.new_set

local T = new_set()

-- Helpers for creating test data
local function create_test_items()
  return {
    {
      value = {
        name = "function_a",
        lnum = 1,
        end_lnum = 10,
        col = 1,
        end_col = 20,
      },
      depth = 0,
    },
    {
      value = {
        name = "nested_function",
        lnum = 2,
        end_lnum = 5,
        col = 3,
        end_col = 15,
      },
      depth = 1,
    },
  }
end

-- State Management Tests
T["SymbolUtils.state"] = new_set()

T["SymbolUtils.state"]["creates proper state object"] = function()
  local state = symbol_utils.create_state("test_namespace")

  h.eq(state.original_win, nil)
  h.eq(state.original_buf, nil)
  h.eq(state.original_pos, nil)
  h.eq(state.original_ft, nil)
  h.eq(type(state.preview_ns), "number")
  h.eq(state.current_request, nil)
end

-- Symbol Finding Tests
T["SymbolUtils.symbol_finding"] = new_set()

T["SymbolUtils.symbol_finding"]["finds containing symbol correctly"] = function()
  local items = create_test_items()

  -- Mock cursor position
  local _original_fn = vim.api.nvim_win_get_cursor
  vim.api.nvim_win_get_cursor = function()
    return { 3, 5 } -- Line 3, Column 6
  end

  local found = symbol_utils.find_containing_symbol(items)
  h.eq(found.value.name, "nested_function")

  vim.api.nvim_win_get_cursor = _original_fn
end

T["SymbolUtils.symbol_finding"]["handles empty items list"] = function()
  local result = symbol_utils.find_containing_symbol({})
  h.eq(result, nil)
end

-- Range Cache Tests
T["SymbolUtils.range_cache"] = new_set()

T["SymbolUtils.range_cache"]["updates symbol ranges cache correctly"] = function()
  local items = create_test_items()
  local cache = {}

  symbol_utils.update_symbol_ranges_cache(items, cache)

  h.eq(#cache, 2)
  h.eq(cache[1].start_line, 1)
  h.eq(cache[1].end_line, 10)
  h.eq(cache[2].start_line, 2)
  h.eq(cache[2].end_line, 5)
end

-- Symbol Jump Tests
T["SymbolUtils.jumping"] = new_set()

T["SymbolUtils.jumping"]["performs jump correctly"] = function()
  local jumped_to = nil
  local _original_fn = vim.api.nvim_win_set_cursor
  vim.api.nvim_win_set_cursor = function(win, pos)
    jumped_to = pos
  end

  local symbol = {
    lnum = 5,
    col = 3,
  }
  local state = { original_win = 1 }

  symbol_utils.jump_to_symbol(symbol, state)
  h.eq(jumped_to[1], 5)
  h.eq(jumped_to[2], 2) -- col - 1

  vim.api.nvim_win_set_cursor = _original_fn
end

-- Filter Parsing Tests
T["SymbolUtils.filtering"] = new_set()

T["SymbolUtils.filtering"]["parses symbol filters correctly"] = function()
  local config = {
    filter_symbol_types = {
      fn = {
        kinds = { "Function", "Method" },
        description = "Functions",
      },
    },
  }

  local result = symbol_utils.parse_symbol_filter("/fn test", config)
  h.eq(result.kinds[1], "Function")
  h.eq(result.kinds[2], "Method")
  h.eq(result.remaining, " test")
end

-- Picker Tests
T["SymbolUtils.picker"] = new_set()

T["SymbolUtils.picker"]["handles empty items list"] = function()
  local notified = false
  local _original_notify = vim.notify
  vim.notify = function(msg)
    if msg:match("doesn't match") then
      notified = true
    end
  end

  symbol_utils.show_picker({}, {}, {}, {}, {}, "Test", {}, false, "watchtower")
  h.eq(notified, true)

  vim.notify = _original_notify
end

T["SymbolUtils.picker"]["keeps persistent sidebar empty without notifying"] = function()
  local notified = false
  local picked_items = nil
  local picked_opts = nil
  local _original_notify = vim.notify
  local _original_get_current_win = vim.api.nvim_get_current_win
  local _original_get_current_buf = vim.api.nvim_get_current_buf
  local _original_win_is_valid = vim.api.nvim_win_is_valid
  local _original_buf_is_valid = vim.api.nvim_buf_is_valid
  local _original_win_get_buf = vim.api.nvim_win_get_buf
  local _original_win_get_cursor = vim.api.nvim_win_get_cursor
  local _original_bo = vim.bo

  vim.notify = function()
    notified = true
  end
  vim.api.nvim_get_current_win = function()
    return 7
  end
  vim.api.nvim_get_current_buf = function()
    return 3
  end
  vim.api.nvim_win_is_valid = function(win)
    return win == 7
  end
  vim.api.nvim_buf_is_valid = function(buf)
    return buf == 3
  end
  vim.api.nvim_win_get_buf = function(win)
    return 3
  end
  vim.api.nvim_win_get_cursor = function(win)
    return { 1, 0 }
  end
  vim.bo = setmetatable({
    [3] = { filetype = "lua" },
  }, {
    __index = function()
      return { filetype = "lua" }
    end,
  })

  local fake_selecta = {
    pick = function(items, opts)
      picked_items = items
      picked_opts = opts
      return {
        picker_id = "sidebar-test",
        active = true,
        win = 11,
        prompt_buf = nil,
        get_query_string = function()
          return ""
        end,
      }
    end,
    close_picker = function() end,
  }

  symbol_utils.show_picker(
    {},
    { namespace = "namu_symbols_preview", original_win = 7, original_buf = 3, original_pos = { 1, 0 } },
    {
      window = { layout = "right" },
      movement = {},
      display = {},
      current_highlight = {},
      custom_keymaps = {},
      multiselect = { enabled = false },
      preview = { highlight_on_move = false, highlight_mode = "always" },
    },
    {
      clear_preview_highlight = function() end,
      find_symbol_index = function()
        return nil
      end,
      apply_highlights = function() end,
    },
    fake_selecta,
    " Symbols ",
    { title = "Namu" },
    false,
    "buffer",
    nil,
    function() end
  )

  h.eq(notified, false)
  h.eq(type(picked_items), "table")
  h.eq(#picked_items, 0)
  h.eq(picked_opts.stay_open, true)

  vim.notify = _original_notify
  vim.api.nvim_get_current_win = _original_get_current_win
  vim.api.nvim_get_current_buf = _original_get_current_buf
  vim.api.nvim_win_is_valid = _original_win_is_valid
  vim.api.nvim_buf_is_valid = _original_buf_is_valid
  vim.api.nvim_win_get_buf = _original_win_get_buf
  vim.api.nvim_win_get_cursor = _original_win_get_cursor
  vim.bo = _original_bo
end

return T
