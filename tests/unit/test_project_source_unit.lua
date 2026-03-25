local project_source_mod = require('metabuffer.project.source')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T['project bootstrap prefers lazy streaming on startup even below estimate threshold'] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, 'p')
  local current_path = tmpdir .. '/current.lua'
  local a_path = tmpdir .. '/a.lua'
  local b_path = tmpdir .. '/b.lua'
  vim.fn.writefile({ 'current file' }, current_path)
  vim.fn.writefile({ 'a file' }, a_path)
  vim.fn.writefile({ 'b file' }, b_path)

  local state = {
    current = current_path,
    reads = 0,
  }

  local project_source = project_source_mod.new({
    settings = {
      ['project-max-total-lines'] = 500000,
      ['project-lazy-min-estimated-lines'] = 10000,
      ['project-lazy-chunk-size'] = 8,
      ['project-lazy-refresh-debounce-ms'] = 0,
      ['project-lazy-refresh-min-ms'] = 0,
    },
    ['truthy?'] = function(v)
      return v == true
    end,
    ['selected-ref'] = function()
      return nil
    end,
    ['canonical-path'] = function(path)
      return path
    end,
    ['current-buffer-path'] = function()
      return state.current
    end,
    ['path-under-root?'] = function()
      return true
    end,
    ['allow-project-path?'] = function()
      return true
    end,
    ['project-file-list'] = function()
      return { a_path, b_path }
    end,
    ['binary-file?'] = function()
      return false
    end,
    ['read-file-lines-cached'] = function()
      state.reads = state.reads + 1
      return { 'one', 'two' }
    end,
    ['read-file-view-cached'] = function()
      state.reads = state.reads + 1
      return { lines = { 'one', 'two' }, ['line-map'] = { 1, 2 } }
    end,
    ['session-active?'] = function()
      return true
    end,
    ['lazy-streaming-allowed?'] = function()
      return true
    end,
    ['on-prompt-changed'] = function()
    end,
    ['apply-prompt-lines-now!'] = function()
    end,
    ['prompt-has-active-query?'] = function()
      return false
    end,
    ['now-ms'] = function()
      return 0
    end,
    ['prompt-update-delay-ms'] = function()
      return 0
    end,
    ['schedule-prompt-update!'] = function()
    end,
    ['restore-meta-view!'] = function()
    end,
    ['update-info-window'] = function()
    end,
  })

  local session = {
    ['project-mode'] = true,
    ['project-bootstrapped'] = false,
    ['lazy-mode'] = true,
    ['effective-include-hidden'] = false,
    ['effective-include-ignored'] = false,
    ['effective-include-deps'] = false,
    ['effective-include-binary'] = false,
    ['effective-include-hex'] = false,
    ['effective-include-files'] = false,
    ['single-content'] = { 'cur one', 'cur two' },
    ['single-refs'] = {
      { path = state.current, lnum = 1, line = 'cur one' },
      { path = state.current, lnum = 2, line = 'cur two' },
    },
    ['source-buf'] = nil,
    meta = {
      buf = {
        content = { 'cur one', 'cur two' },
        ['source-refs'] = {},
        ['all-indices'] = {},
        indices = {},
        ['closest-index'] = function()
          return 1
        end,
      },
      ['selected_index'] = 0,
      ['selected_line'] = function()
        return 1
      end,
    },
  }

  local ok, err = pcall(function()
    project_source['apply-source-set!'](session)

    eq(session['lazy-stream-done'], false)
    eq(session['lazy-stream-total'], 2)
    eq(#session.meta.buf.content, 2)
    eq(state.reads, 0)
  end)
  vim.fn.delete(tmpdir, 'rf')
  if not ok then
    error(err)
  end
end

T['project source prefilter runs before max line cap'] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, 'p')
  local current_path = tmpdir .. '/current.lua'
  local a_path = tmpdir .. '/a.lua'
  local b_path = tmpdir .. '/b.lua'
  vim.fn.writefile({ 'current file' }, current_path)
  vim.fn.writefile({ 'a file' }, a_path)
  vim.fn.writefile({ 'b file' }, b_path)

  local state = {
    current = current_path,
    reads = {},
  }

  local project_source = project_source_mod.new({
    settings = {
      ['project-max-total-lines'] = 3,
      ['project-max-file-bytes'] = 1024 * 1024,
      ['project-lazy-min-estimated-lines'] = 10000,
      ['project-lazy-chunk-size'] = 8,
      ['project-lazy-refresh-debounce-ms'] = 0,
      ['project-lazy-refresh-min-ms'] = 0,
    },
    ['truthy?'] = function(v)
      return v == true
    end,
    ['selected-ref'] = function()
      return nil
    end,
    ['canonical-path'] = function(path)
      return path
    end,
    ['current-buffer-path'] = function()
      return state.current
    end,
    ['path-under-root?'] = function()
      return true
    end,
    ['allow-project-path?'] = function()
      return true
    end,
    ['project-file-list'] = function()
      return { a_path, b_path }
    end,
    ['binary-file?'] = function()
      return false
    end,
    ['read-file-lines-cached'] = function(path)
      state.reads[#state.reads + 1] = path
      if path == a_path then
        return { 'miss a1', 'keep from a', 'miss a2' }
      end
      if path == b_path then
        return { 'miss b1', 'miss b2', 'keep from b' }
      end
      return {}
    end,
    ['read-file-view-cached'] = function(path)
      state.reads[#state.reads + 1] = path
      if path == a_path then
        return { lines = { 'miss a1', 'keep from a', 'miss a2' }, ['line-map'] = { 1, 2, 3 } }
      end
      if path == b_path then
        return { lines = { 'miss b1', 'miss b2', 'keep from b' }, ['line-map'] = { 1, 2, 3 } }
      end
      return { lines = {}, ['line-map'] = {} }
    end,
    ['session-active?'] = function()
      return true
    end,
    ['lazy-streaming-allowed?'] = function()
      return false
    end,
    ['on-prompt-changed'] = function()
    end,
    ['apply-prompt-lines-now!'] = function()
    end,
    ['prompt-has-active-query?'] = function()
      return true
    end,
    ['now-ms'] = function()
      return 0
    end,
    ['prompt-update-delay-ms'] = function()
      return 0
    end,
    ['schedule-prompt-update!'] = function()
    end,
    ['restore-meta-view!'] = function()
    end,
    ['update-info-window'] = function()
    end,
  })

  local session = {
    ['project-mode'] = true,
    ['project-bootstrapped'] = true,
    ['lazy-mode'] = false,
    ['prefilter-mode'] = true,
    ['last-parsed-query'] = {
      lines = { 'keep' },
    },
    ['effective-include-hidden'] = false,
    ['effective-include-ignored'] = false,
    ['effective-include-deps'] = false,
    ['effective-include-binary'] = false,
    ['effective-include-hex'] = false,
    ['effective-include-files'] = false,
    ['single-content'] = { 'miss cur1', 'keep from current', 'miss cur2' },
    ['single-refs'] = {
      { path = state.current, lnum = 1, line = 'miss cur1' },
      { path = state.current, lnum = 2, line = 'keep from current' },
      { path = state.current, lnum = 3, line = 'miss cur2' },
    },
    ['source-buf'] = nil,
    meta = {
      ignorecase = function()
        return false
      end,
      buf = {
        content = {},
        ['source-refs'] = {},
        ['all-indices'] = {},
        indices = {},
        ['closest-index'] = function()
          return 1
        end,
      },
      ['selected_index'] = 0,
      ['selected_line'] = function()
        return 1
      end,
    },
  }

  local ok, err = pcall(function()
    project_source['apply-source-set!'](session)

    eq(session.meta.buf.content, {
      'keep from current',
      'keep from a',
      'keep from b',
    })
    eq(#session.meta.buf['source-refs'], 3)
  end)
  vim.fn.delete(tmpdir, 'rf')
  if not ok then
    error(err)
  end
end

T['project source keeps original source line numbers from transformed views'] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, 'p')
  local current_path = tmpdir .. '/current.lua'
  local a_path = tmpdir .. '/a.lua'
  vim.fn.writefile({ 'current file' }, current_path)
  vim.fn.writefile({ 'a file' }, a_path)

  local project_source = project_source_mod.new({
    settings = {
      ['project-max-total-lines'] = 500000,
      ['project-max-file-bytes'] = 1024 * 1024,
      ['project-lazy-min-estimated-lines'] = 10000,
      ['project-lazy-chunk-size'] = 8,
      ['project-lazy-refresh-debounce-ms'] = 0,
      ['project-lazy-refresh-min-ms'] = 0,
    },
    ['truthy?'] = function(v)
      return v == true
    end,
    ['selected-ref'] = function()
      return nil
    end,
    ['canonical-path'] = function(path)
      return path
    end,
    ['current-buffer-path'] = function()
      return current_path
    end,
    ['path-under-root?'] = function()
      return true
    end,
    ['allow-project-path?'] = function()
      return true
    end,
    ['project-file-list'] = function()
      return { a_path }
    end,
    ['binary-file?'] = function()
      return false
    end,
    ['read-file-lines-cached'] = function()
      return {}
    end,
    ['read-file-view-cached'] = function()
      return {
        lines = { 'one', 'pretty a', 'pretty b', 'tail' },
        ['line-map'] = { 1, 2, 2, 3 },
      }
    end,
    ['session-active?'] = function()
      return true
    end,
    ['lazy-streaming-allowed?'] = function()
      return false
    end,
    ['on-prompt-changed'] = function()
    end,
    ['apply-prompt-lines-now!'] = function()
    end,
    ['prompt-has-active-query?'] = function()
      return true
    end,
    ['now-ms'] = function()
      return 0
    end,
    ['prompt-update-delay-ms'] = function()
      return 0
    end,
    ['schedule-prompt-update!'] = function()
    end,
    ['restore-meta-view!'] = function()
    end,
    ['update-info-window'] = function()
    end,
  })

  local session = {
    ['project-mode'] = true,
    ['project-bootstrapped'] = true,
    ['lazy-mode'] = false,
    ['prefilter-mode'] = false,
    ['effective-include-hidden'] = false,
    ['effective-include-ignored'] = false,
    ['effective-include-deps'] = false,
    ['effective-include-binary'] = false,
    ['effective-include-files'] = false,
    ['effective-transforms'] = { json = true },
    ['single-content'] = {},
    ['single-refs'] = {},
    ['source-buf'] = nil,
    meta = {
      ignorecase = function()
        return false
      end,
      buf = {
        content = {},
        ['source-refs'] = {},
        ['all-indices'] = {},
        indices = {},
        ['closest-index'] = function()
          return 1
        end,
      },
      ['selected_index'] = 0,
      ['selected_line'] = function()
        return 1
      end,
    },
  }

  local ok, err = pcall(function()
    project_source['apply-source-set!'](session)

    eq(session.meta.buf.content, { 'one', 'pretty a', 'pretty b', 'tail' })
    eq(session.meta.buf['source-refs'][2].lnum, 2)
    eq(session.meta.buf['source-refs'][3].lnum, 2)
    eq(session.meta.buf['source-refs'][4].lnum, 3)
  end)
  vim.fn.delete(tmpdir, 'rf')
  if not ok then
    error(err)
  end
end

return T
