local eq = MiniTest.expect.equality
local file_info = require('metabuffer.source.file_info')

local T = MiniTest.new_set()

local function current_session(source_buf)
  return require('metabuffer.router')['active-by-source'][source_buf]
end

local function wait_for(pred, timeout_ms)
  eq(vim.wait(timeout_ms or 3000, pred, 20), true)
end

local function type_prompt_text(session, text)
  vim.api.nvim_set_current_win(session['prompt-win'])
  vim.cmd('startinsert')
  vim.api.nvim_input(text)
end

T['regular meta keeps info window with line numbers only'] = function()
  vim.cmd('enew')
  local source_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
    'alpha one',
    'alpha two',
    'beta three',
    'alpha four',
  })

  vim.cmd('Meta')

  wait_for(function()
    return current_session(source_buf) ~= nil
  end)

  local session = current_session(source_buf)
  type_prompt_text(session, 'alpha')

  wait_for(function()
    local s = current_session(source_buf)
    return s and s.meta and #(s.meta.buf.indices or {}) == 3
  end)

  wait_for(function()
    local s = current_session(source_buf)
    return s
      and s['info-win']
      and vim.api.nvim_win_is_valid(s['info-win'])
      and s['info-buf']
      and vim.api.nvim_buf_is_valid(s['info-buf'])
  end)

  local info_row = vim.api.nvim_win_get_cursor(session['info-win'])[1]
  local info_line = vim.api.nvim_buf_get_lines(session['info-buf'], info_row - 1, info_row, false)[1] or ''

  eq(type(info_line), 'string')
  eq(string.find(info_line, 'alpha', 1, true) == nil, true)
  eq(string.find(info_line, 'one', 1, true) == nil, true)
  eq(string.find(info_line, '1', 1, true) ~= nil, true)
end

T['aligned meta suffix highlights full compact age token'] = function()
  local laid = file_info['aligned-meta-suffix']('240101  3d\t Alice', 24)
  local age_hl = nil

  for _, hl in ipairs(laid['suffix-highlights'] or {}) do
    if hl.hl == 'MetaFileAgeDay' then
      age_hl = hl
    end
  end

  eq(type(age_hl), 'table')
  eq(string.sub(laid.text, age_hl.start + 1, age_hl['end']), '3d')
end

return T
