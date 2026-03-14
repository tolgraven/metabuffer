local query_flow = require('metabuffer.router.query_flow')
local router_util = require('metabuffer.router.util')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function mk_session(prompt_buf)
  local session = {
    closing = false,
    ['prompt-buf'] = prompt_buf,
    ['project-mode'] = true,
    ['include-hidden'] = false,
    ['include-ignored'] = false,
    ['include-deps'] = false,
    ['include-binary'] = false,
    ['include-hex'] = false,
    ['include-files'] = false,
    ['effective-include-hidden'] = false,
    ['effective-include-ignored'] = false,
    ['effective-include-deps'] = false,
    ['effective-include-binary'] = false,
    ['effective-include-hex'] = false,
    ['effective-include-files'] = false,
    ['prefilter-mode'] = true,
    ['lazy-mode'] = true,
    ['expansion-mode'] = 'none',
    ['prompt-last-applied-text'] = '',
    meta = {
      _prev_text = 'cached',
      ['_filter-cache'] = { a = true },
      buf = {
        buffer = vim.api.nvim_get_current_buf(),
        content = { 'one', 'two', 'three' },
        indices = { 1, 2, 3 },
      },
    },
  }
  session.meta['on-update'] = function()
    session._update_calls = (session._update_calls or 0) + 1
  end
  session.meta['refresh_statusline'] = function()
    session._status_calls = (session._status_calls or 0) + 1
  end
  session.meta['set-query-lines'] = function(lines)
    session._query_lines = lines
  end
  return session
end

local function mk_deps(overrides)
  local state = {
    apply_calls = 0,
    info_calls = 0,
  }
  local deps = {
    ['query-mod'] = {
      ['parse-query-lines'] = function(lines)
        return {
          lines = lines,
          ['include-hidden'] = nil,
          ['include-ignored'] = nil,
          ['include-deps'] = nil,
          prefilter = nil,
          lazy = nil,
        }
      end,
      ['query-lines-has-active?'] = function(lines)
        for _, line in ipairs(lines) do
          if vim.trim(line) ~= '' then
            return true
          end
        end
        return false
      end,
      ['truthy?'] = function(v)
        return v == true
      end,
    },
    ['project-source'] = {
      ['apply-source-set!'] = function()
        state.apply_calls = state.apply_calls + 1
      end,
    },
    ['update-info-window'] = function()
      state.info_calls = state.info_calls + 1
    end,
    settings = {
      ['project-lazy-prefilter-enabled'] = true,
    },
  }
  if overrides then
    deps = vim.tbl_deep_extend('force', deps, overrides)
  end
  deps._state = state
  return deps
end

T['apply-prompt-lines invalidates filter cache when project flags transition'] = function()
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { 'needle' })

  local session = mk_session(prompt_buf)
  local deps = mk_deps({
    ['query-mod'] = {
      ['parse-query-lines'] = function(lines)
        return {
          lines = lines,
          ['include-hidden'] = true,
          ['include-ignored'] = nil,
          ['include-deps'] = nil,
          prefilter = nil,
          lazy = nil,
        }
      end,
    },
  })

  query_flow['apply-prompt-lines!'](deps, session)

  eq(session['effective-include-hidden'], true)
  eq(type(session.meta['_filter-cache']), 'table')
  eq(next(session.meta['_filter-cache']), nil)
  eq(session.meta['_filter-cache-line-count'], 3)
  eq(deps._state.apply_calls >= 1, true)
end

T['apply-prompt-lines skips synchronous meta update on pure project flag changes'] = function()
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { 'needle' })

  local session = mk_session(prompt_buf)
  session['prompt-last-applied-text'] = 'needle'
  session.meta['on-update'] = function()
    error('on-update should not run for pure project flag changes')
  end

  local deps = mk_deps({
    ['query-mod'] = {
      ['parse-query-lines'] = function(lines)
        return {
          lines = lines,
          ['include-hidden'] = true,
          ['include-ignored'] = nil,
          ['include-deps'] = nil,
          ['include-binary'] = nil,
          ['include-hex'] = nil,
          ['include-files'] = nil,
          prefilter = nil,
          lazy = nil,
          expansion = nil,
        }
      end,
    },
  })
  deps['project-source']['schedule-source-set-rebuild!'] = function()
    deps._state.apply_calls = deps._state.apply_calls + 1
  end
  deps['project-source']['apply-source-set!'] = nil

  query_flow['apply-prompt-lines!'](deps, session)

  eq(session._status_calls >= 1, true)
  eq(deps._state.apply_calls >= 1, true)
end

T['apply-prompt-lines does not rebuild project source on text-only changes'] = function()
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { 'meta token' })

  local session = mk_session(prompt_buf)
  local deps = mk_deps()

  query_flow['apply-prompt-lines!'](deps, session)
  local first_calls = deps._state.apply_calls

  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { 'meta' })
  query_flow['apply-prompt-lines!'](deps, session)

  eq(session['prompt-last-applied-text'], 'meta')
  eq(deps._state.apply_calls, first_calls)
end

T['prompt-lines ignores non-buffer prompt handles'] = function()
  eq(router_util['prompt-lines']({ ['prompt-buf'] = { bogus = true } }), {})
end

return T
