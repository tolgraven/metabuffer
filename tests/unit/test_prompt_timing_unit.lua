local prompt = require('metabuffer.router.prompt')
local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local function mk_settings(overrides)
  local base = {
    ['prompt-update-debounce-ms'] = 170,
    ['prompt-short-query-extra-ms'] = { 180, 120, 70 },
    ['prompt-size-scale-thresholds'] = { 2000, 10000, 50000 },
    ['prompt-size-scale-extra'] = { 0, 2, 6, 10 },
  }
  return vim.tbl_extend('force', base, overrides or {})
end

T['prompt-update-delay-ms scales by query length and pool size'] = function()
  local settings = mk_settings()
  local query_mod = {
    ['parse-query-lines'] = function(lines)
      return { lines = lines }
    end,
  }
  local prompt_lines = function()
    return { 'abc' }
  end
  local session = {
    ['project-mode'] = false,
    ['lazy-stream-done'] = true,
    meta = { buf = { indices = { 1, 2, 3 } } },
  }

  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 240)

  prompt_lines = function()
    return { 'ab' }
  end
  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 290)

  prompt_lines = function()
    return { 'a' }
  end
  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 350)
end

T['prompt-update-delay-ms adds project streaming and size penalties'] = function()
  local settings = mk_settings()
  local query_mod = {
    ['parse-query-lines'] = function(lines)
      return { lines = lines }
    end,
  }
  local prompt_lines = function()
    return { 'querytext' }
  end
  local session = {
    ['project-mode'] = true,
    ['lazy-stream-done'] = false,
    meta = { buf = { indices = {} } },
  }

  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 172)

  session.meta.buf.indices = vim.tbl_map(function(i)
    return i
  end, vim.fn.range(1, 3000))
  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 174)

  session.meta.buf.indices = vim.tbl_map(function(i)
    return i
  end, vim.fn.range(1, 12000))
  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 178)

  session.meta.buf.indices = vim.tbl_map(function(i)
    return i
  end, vim.fn.range(1, 60000))
  eq(prompt['prompt-update-delay-ms'](settings, query_mod, prompt_lines, session), 182)
end

return T
