local M = {}

local state = {
  primary = nil, -- { token: string, restore: fun()|nil, close: fun(picker_state), picker_state: SelectaState|nil }
  source_win = nil,
  source_buf = nil,
  source_pos = nil,
  restoring = false,
  suspending = false,
}

local function is_valid_win(win)
  return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
  return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

function M.is_namu_buffer(bufnr)
  if not is_valid_buf(bufnr) then
    return false
  end
  local ft = vim.bo[bufnr].filetype or ""
  return ft:match("^namu") ~= nil
end

function M.is_namu_window(win)
  if not is_valid_win(win) then
    return false
  end
  return M.is_namu_buffer(vim.api.nvim_win_get_buf(win))
end

function M.capture_source_from_current()
  local win = vim.api.nvim_get_current_win()
  if M.is_namu_window(win) then
    return
  end
  state.source_win = win
  state.source_buf = vim.api.nvim_win_get_buf(win)
  state.source_pos = vim.api.nvim_win_get_cursor(win)
end

function M.get_source_context()
  if is_valid_win(state.source_win) then
    local bufnr = vim.api.nvim_win_get_buf(state.source_win)
    if is_valid_buf(bufnr) then
      return {
        win = state.source_win,
        buf = bufnr,
        pos = vim.api.nvim_win_get_cursor(state.source_win),
        ft = vim.bo[bufnr].filetype,
      }
    end
  end

  if is_valid_buf(state.source_buf) then
    return {
      win = nil,
      buf = state.source_buf,
      pos = state.source_pos,
      ft = vim.bo[state.source_buf].filetype,
    }
  end

  return nil
end

function M.has_primary()
  return state.primary ~= nil
end

function M.is_restoring()
  return state.restoring
end

function M.is_suspending()
  return state.suspending
end

function M.get_primary()
  return state.primary
end

function M.is_primary_token(token)
  return state.primary and state.primary.token == token
end

function M.set_primary(primary)
  state.primary = primary
  state.restoring = false
end

function M.clear_primary()
  state.primary = nil
end

function M.with_suspending(fn)
  state.suspending = true
  local ok, err = pcall(fn)
  state.suspending = false
  if not ok then
    error(err)
  end
end

function M.close_primary()
  local primary = state.primary
  if not primary or not primary.picker_state or not primary.close then
    return
  end
  if primary.picker_state.active then
    pcall(primary.close, primary.picker_state)
  end
end

function M.request_restore_primary()
  local primary = state.primary
  if not primary or type(primary.restore) ~= "function" then
    return
  end

  if state.restoring then
    return
  end

  state.restoring = true
  vim.schedule(function()
    local ok = pcall(primary.restore)
    if not ok then
      state.restoring = false
    end
  end)

  -- Safety net: if the restore callback doesn't end up creating a new primary picker (e.g. async failure),
  -- don't keep the manager stuck in restoring mode forever.
  vim.defer_fn(function()
    if state.restoring then
      state.restoring = false
    end
  end, 10000)
end

return M
