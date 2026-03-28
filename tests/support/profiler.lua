local M = {}
local runtime_guard = require('tests.support.runtime_guard')

local enabled = false
local current_case = nil
local case_order = {}
local file_totals = nil
local output_path = nil
local file_finished = false
local case_timings = nil
local finalize_group = nil
local pack = table.pack or function(...)
  return { n = select('#', ...), ... }
end
local unpack = table.unpack or unpack

local function truthy(x)
  return x == '1' or x == 'true' or x == 'yes' or x == 'on'
end

local function hr_ms()
  return vim.loop.hrtime() / 1e6
end

local function cpu_ms()
  local uv = vim.uv or vim.loop
  local usage = uv.getrusage and uv.getrusage() or nil
  if not usage then
    return 0
  end
  local user = (usage.utime.sec * 1000) + (usage.utime.usec / 1000)
  local sys = (usage.stime.sec * 1000) + (usage.stime.usec / 1000)
  return user + sys
end

local function case_name()
  local case = MiniTest.current and MiniTest.current.case or nil
  local desc = case and case.desc or {}
  if type(desc) ~= 'table' then
    return tostring(desc)
  end
  local out = {}
  for _, part in ipairs(desc) do
    out[#out + 1] = tostring(part)
  end
  return table.concat(out, ' > ')
end

local function record_span(kind, label, ms)
  if not (enabled and current_case and ms > 0) then
    return
  end
  current_case[kind] = (current_case[kind] or 0) + ms
  current_case.spans[#current_case.spans + 1] = {
    kind = kind,
    label = label,
    ms = ms,
  }
end

local function top_spans(case_stats, n)
  local spans = vim.deepcopy(case_stats.spans or {})
  table.sort(spans, function(a, b) return a.ms > b.ms end)
  local out = {}
  for i = 1, math.min(n or 3, #spans) do
    out[#out + 1] = spans[i]
  end
  return out
end

local function print_case_summary(case_stats, idx)
  local blocked = math.max(0, case_stats.wall - case_stats.cpu)
  local lines = {
    string.format(
    '[mini-profile]   %02d. %s | wall=%.1fms cpu=%.1fms blocked=%.1fms wait=%.1fms sleep=%.1fms child=%.1fms',
    idx,
    case_stats.name,
    case_stats.wall,
    case_stats.cpu,
    blocked,
    case_stats.wait or 0,
    case_stats.sleep or 0,
    case_stats.child or 0
    ),
  }
  for _, item in ipairs(top_spans(case_stats, 3)) do
    lines[#lines + 1] = string.format(
      '[mini-profile]        %s | %s | %.1fms',
      item.kind,
      item.label,
      item.ms
    )
  end
  return lines
end

local function emit_lines(lines)
  if not enabled then
    return
  end
  if output_path and output_path ~= '' then
    vim.fn.writefile(lines, output_path, 'a')
    return
  end
  for _, line in ipairs(lines) do
    print(line)
  end
end

local function print_case_timing(name, ms)
  return string.format('[mini-runner] CASE DONE  %s | %.1fms', name, ms)
end

function M.enabled()
  return enabled
end

function M.caller_label(offset, prefix)
  local info = debug.getinfo((offset or 1) + 1, 'Sl')
  if not info then
    return prefix or 'unknown'
  end
  local src = info.short_src or info.source or '?'
  local line = info.currentline or 0
  if prefix then
    return string.format('%s @ %s:%d', prefix, src, line)
  end
  return string.format('%s:%d', src, line)
end

function M.measure(kind, label, fn)
  if not enabled then
    return fn()
  end
  local wall0 = hr_ms()
  local out = pack(fn())
  record_span(kind, label, hr_ms() - wall0)
  return unpack(out, 1, out.n)
end

function M.record(kind, label, ms)
  record_span(kind, label, ms)
end

function M.start_case()
  local name = case_name()
  io.stdout:write(string.format('\n[mini-runner] CASE START %s\n', name))
  io.stdout:flush()
  if not enabled then
    current_case = { name = name, wall0 = hr_ms() }
    return
  end
  current_case = {
    name = name,
    wall0 = hr_ms(),
    cpu0 = cpu_ms(),
    spans = {},
    wait = 0,
    sleep = 0,
    child = 0,
  }
end

function M.finish_case()
  if not current_case then
    return
  end
  current_case.wall = hr_ms() - current_case.wall0
  local name = current_case.name
  local wall = current_case.wall
  case_timings[#case_timings + 1] = { name = name, ms = wall }
  io.stdout:write('\n' .. print_case_timing(name, wall) .. '\n')
  io.stdout:flush()
  if not enabled then
    current_case = nil
    return
  end
  current_case.cpu = math.max(0, cpu_ms() - current_case.cpu0)
  current_case.wall0 = nil
  current_case.cpu0 = nil
  case_order[#case_order + 1] = current_case
  file_totals.wall = file_totals.wall + current_case.wall
  file_totals.cpu = file_totals.cpu + current_case.cpu
  file_totals.wait = file_totals.wait + (current_case.wait or 0)
  file_totals.sleep = file_totals.sleep + (current_case.sleep or 0)
  file_totals.child = file_totals.child + (current_case.child or 0)
  emit_lines(print_case_summary(current_case, #case_order))
  current_case = nil
end

function M.finish_file()
  if file_finished then
    return
  end
  file_finished = true
  if type(case_timings) == 'table' and #case_timings > 0 then
    io.stdout:write('\n[mini-runner] CASE TIMINGS SUMMARY\n')
    for i, item in ipairs(case_timings) do
      io.stdout:write(string.format('[mini-runner]   %02d. %s | %.1fms\n', i, item.name, item.ms))
    end
    io.stdout:flush()
  end
  if not enabled then
    return
  end
  table.sort(case_order, function(a, b) return a.wall > b.wall end)
  local lines = {
    string.format(
    '[mini-profile] FILE SUMMARY | cases=%d wall=%.1fms cpu=%.1fms blocked=%.1fms wait=%.1fms sleep=%.1fms child=%.1fms',
    #case_order,
    file_totals.wall,
    file_totals.cpu,
    math.max(0, file_totals.wall - file_totals.cpu),
    file_totals.wait,
    file_totals.sleep,
    file_totals.child
    ),
  }
  for i, case_stats in ipairs(case_order) do
    vim.list_extend(lines, print_case_summary(case_stats, i))
  end
  emit_lines(lines)
end

function M.wrap_minitest_new_set()
  if not enabled or MiniTest._meta_profile_wrapped then
    return
  end
  local original = MiniTest.new_set

  MiniTest.new_set = function(opts, tbl)
    local caller = debug.getinfo(2, 'S')
    local src = caller and (caller.short_src or caller.source) or ''
    if src:find('mini/test.lua', 1, true) then
      return original(opts, tbl)
    end

    opts = opts or {}
    opts.hooks = opts.hooks or {}

    local pre_case = opts.hooks.pre_case
    local post_case = opts.hooks.post_case
    local post_once = opts.hooks.post_once

    opts.hooks.pre_case = function()
      runtime_guard.clear()
      M.start_case()
      if pre_case then
        pre_case()
      end
    end
    opts.hooks.post_case = function()
      if post_case then
        post_case()
      end
      runtime_guard.assert_clean(MiniTest.expect.equality)
      M.finish_case()
    end
    opts.hooks.post_once = function()
      if post_once then
        post_once()
      end
      M.finish_file()
    end

    return original(opts, tbl)
  end

  MiniTest._meta_profile_wrapped = true
end

function M.setup()
  enabled = truthy((vim.env.TEST_PROFILE or ''):lower())
  output_path = vim.env.TEST_PROFILE_PATH or ''
  file_finished = false
  case_timings = {}
  case_order = {}
  file_totals = {
    wall = 0,
    cpu = 0,
    wait = 0,
    sleep = 0,
    child = 0,
  }
  if finalize_group ~= nil then
    pcall(vim.api.nvim_del_augroup_by_id, finalize_group)
  end
  finalize_group = vim.api.nvim_create_augroup('MetaTestProfiler', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = finalize_group,
    callback = function()
      if current_case ~= nil then
        pcall(M.finish_case)
      end
      pcall(M.finish_file)
    end,
  })
  M.wrap_minitest_new_set()
end

return M
