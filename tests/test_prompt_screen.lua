local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality

local debug_dump_path = "/tmp/metabuffer-mini-integration.log"

local function wait_for(pred, timeout_ms)
  local ok = vim.wait(timeout_ms or 3000, pred, 20)
  eq(ok, true)
end

local function child_setup()
  local root = vim.fn.getcwd()
  child.restart(
    { "-u", root .. "/tests/minimal_init.lua", "-n", "-i", "NONE" },
    { connection_timeout = 20000 }
  )
  child.o.hidden = true
  child.o.swapfile = false
  child.cmd("cd " .. root)
  child.lua(string.format([[
    _G.__meta_debug_dump_path = %q
    local ok = pcall(vim.fn.delete, _G.__meta_debug_dump_path)
    if not ok then end
  ]], debug_dump_path))
end

local function open_meta_with_lines(lines)
  child.cmd("enew")
  child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  child.cmd("Meta")

  wait_for(function()
    return child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end)

  wait_for(function()
    local mode = child.fn.mode(1)
    return mode == "i" or mode == "ic" or mode == "ix"
  end)
end

local function session_query_text()
  return child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return '' end
      return table.concat((s.meta['query-lines'] or {}), '\n')
    end)()
  ]])
end

local function session_hit_count()
  return child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return -1 end
      return #(s.meta.buf.indices or {})
    end)()
  ]])
end

local function session_source_path_count()
  return child.lua_get([[
    (function()
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      if not s then return -1 end
      local idxs = s.meta.buf.indices or {}
      local refs = s.meta.buf['source-refs'] or {}
      local seen = {}
      local n = 0
      for _, src_idx in ipairs(idxs) do
        local ref = refs[src_idx]
        local path = ref and ref.path or ''
        if path ~= '' and not seen[path] then
          seen[path] = true
          n = n + 1
        end
      end
      return n
    end)()
  ]])
end

local function dump_state(tag)
  child.lua(string.format([[
    (function()
      local path = _G.__meta_debug_dump_path
      if not path then return end
      local router = require('metabuffer.router')
      local s = router['active-by-source'][_G.__meta_source_buf]
      local out = {}
      out[#out + 1] = ("--- %s ---")
      if not s then
        out[#out + 1] = "session=nil"
      else
        local q = table.concat((s.meta['query-lines'] or {}), "\\n")
        local hits = #(s.meta.buf.indices or {})
        local refs = s.meta.buf['source-refs'] or {}
        local seen, src = {}, 0
        for _, src_idx in ipairs(s.meta.buf.indices or {}) do
          local ref = refs[src_idx]
          local p = ref and ref.path or ''
          if p ~= '' and not seen[p] then
            seen[p] = true
            src = src + 1
          end
        end
        out[#out + 1] = ("query=" .. q)
        out[#out + 1] = ("hits=" .. tostring(hits))
        out[#out + 1] = ("sources=" .. tostring(src))
        local lines = vim.api.nvim_buf_get_lines(s.meta.buf.buffer, 0, math.min(25, vim.api.nvim_buf_line_count(s.meta.buf.buffer)), false)
        for i, line in ipairs(lines) do
          out[#out + 1] = (string.format("%%03d: %%s", i, line))
        end
      end
      vim.fn.writefile(out, path, "a")
    end)()
  ]], tag))
end

local function type_prompt(keys)
  child.type_keys(0, keys)
  dump_state("type " .. keys)
end

local function type_prompt_slow(keys, per_key_ms)
  child.type_keys(per_key_ms or 80, keys)
  dump_state("type_slow " .. keys)
end

local function open_project_meta_from_file(path)
  child.cmd("edit " .. path)
  child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  child.cmd("Meta!")

  wait_for(function()
    return child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end, 6000)

  wait_for(function()
    local mode = child.fn.mode(1)
    return mode == "i" or mode == "ic" or mode == "ix"
  end)
end

local function make_temp_project()
  return child.lua_get([[
    (function()
      local root = vim.fn.tempname()
      vim.fn.mkdir(root, "p")
      vim.fn.mkdir(root .. "/lua", "p")
      vim.fn.mkdir(root .. "/doc", "p")

      local main = {}
      for i = 1, 200 do
        main[#main + 1] = ("line " .. i .. " plain content")
      end
      for i = 1, 60 do
        main[#main + 1] = ("contains meta token " .. i)
      end
      for i = 1, 20 do
        main[#main + 1] = ("contains metam token " .. i)
      end

      vim.fn.writefile(main, root .. "/main.txt")
      vim.fn.writefile({ "meta docs", "metam docs", "other" }, root .. "/doc/readme.md")
      vim.fn.writefile({ "local metabuffer = true", "local meta = 1", "return metabuffer" }, root .. "/lua/mod.lua")
      return root
    end)()
  ]])
end

local function open_project_meta_in_dir(root, relpath)
  child.cmd("cd " .. root)
  child.cmd("edit " .. root .. "/" .. relpath)
  child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  child.cmd("Meta!")
  wait_for(function()
    return child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end, 6000)
end

local T = MiniTest.new_set({
  hooks = {
    pre_case = child_setup,
    post_once = function()
      if child.is_running() then child.stop() end
    end,
  },
})

T["filters on short tokens with real typing"] = function()
  open_meta_with_lines({
    "lua api",
    "meta plugin",
    "metamorph check",
    "tolerance token",
    "topic branch",
    "other",
  })

  type_prompt("lu")
  wait_for(function() return session_query_text() == "lu" end)
  wait_for(function() return session_hit_count() == 1 end)

  type_prompt("a")
  wait_for(function() return session_query_text() == "lua" end)
  wait_for(function() return session_hit_count() == 1 end)

  type_prompt("<C-u>")
  wait_for(function() return session_query_text() == "" end)
  wait_for(function() return session_hit_count() == 6 end)
end

T["Meta with initial query argument applies immediately"] = function()
  child.cmd("enew")
  child.api.nvim_buf_set_lines(0, 0, -1, false, {
    "alpha",
    "meta plugin",
    "metamorph",
    "other",
  })
  child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  child.cmd("Meta meta")
  wait_for(function()
    return child.lua_get("require('metabuffer.router')['active-by-source'][_G.__meta_source_buf] ~= nil")
  end)
  wait_for(function() return session_query_text() == "meta" end)
  wait_for(function() return session_hit_count() == 2 end)
end

T["meta query applies and metam narrows further"] = function()
  open_meta_with_lines({
    "lua api",
    "meta plugin",
    "metamorph check",
    "tolerance token",
    "topic branch",
    "other",
  })

  type_prompt("meta")
  wait_for(function() return session_query_text() == "meta" end)
  wait_for(function() return session_hit_count() == 2 end)

  type_prompt("m")
  wait_for(function() return session_query_text() == "metam" end)
  wait_for(function() return session_hit_count() == 1 end)
end

T["backspace broadens results"] = function()
  open_meta_with_lines({
    "lua api",
    "meta plugin",
    "metamorph check",
    "tolerance token",
    "topic branch",
    "other",
  })

  type_prompt("tol")
  wait_for(function() return session_query_text() == "tol" end)
  wait_for(function() return session_hit_count() == 1 end)

  type_prompt("<BS>")
  wait_for(function() return session_query_text() == "to" end)
  wait_for(function() return session_hit_count() == 2 end)
end

T["project mode typing+delete updates final state"] = function()
  open_project_meta_from_file("README.md")

  wait_for(function() return session_hit_count() > 0 end, 6000)
  local all_hits = session_hit_count()

  type_prompt("meta")
  wait_for(function() return session_query_text() == "meta" end, 6000)
  wait_for(function() return session_hit_count() < all_hits end, 6000)
  local meta_hits = session_hit_count()

  type_prompt("m")
  wait_for(function() return session_query_text() == "metam" end, 6000)
  wait_for(function() return session_hit_count() <= meta_hits end, 6000)
  local metam_hits = session_hit_count()

  type_prompt("<BS>")
  wait_for(function() return session_query_text() == "meta" end, 6000)
  wait_for(function() return session_hit_count() >= metam_hits end, 6000)
end

T["project mode immediate typing survives lazy stream churn"] = function()
  child.cmd("edit README.md")
  child.lua("_G.__meta_source_buf = vim.api.nvim_get_current_buf()")
  child.cmd("Meta!")

  -- Type immediately, without waiting for bootstrap/lazy stream.
  type_prompt("meta")
  wait_for(function() return session_query_text() == "meta" end, 6000)
  local meta_hits = session_hit_count()

  type_prompt("buffer")
  wait_for(function() return session_query_text() == "metabuffer" end, 6000)
  wait_for(function() return session_hit_count() <= meta_hits end, 6000)

  -- Delete quickly and ensure broadening eventually lands on final state.
  type_prompt("<BS><BS><BS><BS><BS><BS>")
  wait_for(function() return session_query_text() == "meta" end, 6000)
  wait_for(function() return session_hit_count() >= meta_hits end, 6000)
end

T["project mode slow typing meta then metam then delete broadens"] = function()
  open_project_meta_from_file("README.md")

  type_prompt_slow("meta", 80)
  wait_for(function() return session_query_text() == "meta" end, 6000)
  local meta_hits = session_hit_count()
  wait_for(function() return meta_hits > 0 end, 6000)

  type_prompt_slow("m", 80)
  wait_for(function() return session_query_text() == "metam" end, 6000)
  local metam_hits = session_hit_count()
  wait_for(function() return metam_hits <= meta_hits end, 6000)

  type_prompt_slow("<BS>", 80)
  wait_for(function() return session_query_text() == "meta" end, 6000)
  wait_for(function() return session_hit_count() >= metam_hits end, 6000)
end

T["project mode reproducer cadence: meta delayed, metam applies, backspace widens"] = function()
  local root = make_temp_project()
  open_project_meta_in_dir(root, "main.txt")

  wait_for(function() return session_hit_count() > 0 end, 6000)
  local all_hits = session_hit_count()

  vim.loop.sleep(300)
  type_prompt("m")
  vim.loop.sleep(100)
  type_prompt("e")
  vim.loop.sleep(100)
  type_prompt("t")
  vim.loop.sleep(100)
  type_prompt("a")
  vim.loop.sleep(500)
  wait_for(function() return session_query_text() == "meta" end, 6000)
  local meta_hits = session_hit_count()
  wait_for(function() return meta_hits < all_hits end, 6000)

  type_prompt("m")
  vim.loop.sleep(500)
  wait_for(function() return session_query_text() == "metam" end, 6000)
  local metam_hits = session_hit_count()
  wait_for(function() return metam_hits <= meta_hits end, 6000)

  type_prompt("<BS>")
  vim.loop.sleep(200)
  type_prompt("<BS>")
  vim.loop.sleep(200)
  type_prompt("<BS>")
  vim.loop.sleep(200)
  type_prompt("<BS>")
  vim.loop.sleep(200)
  type_prompt("<BS>")
  wait_for(function() return session_query_text() == "" end, 6000)
  wait_for(function() return session_hit_count() == all_hits end, 6000)
end

T["project mode clear query broadens while keeping multi-source context"] = function()
  local root = make_temp_project()
  open_project_meta_in_dir(root, "main.txt")
  wait_for(function() return session_hit_count() > 0 end, 6000)
  local all_hits = session_hit_count()
  wait_for(function() return session_source_path_count() > 1 end, 6000)
  local all_sources = session_source_path_count()

  type_prompt("metam")
  wait_for(function() return session_query_text() == "metam" end, 6000)
  wait_for(function() return session_hit_count() < all_hits end, 6000)

  type_prompt("<C-u>")
  wait_for(function() return session_query_text() == "" end, 6000)
  wait_for(function() return session_hit_count() == all_hits end, 6000)
  wait_for(function() return session_source_path_count() == all_sources end, 6000)
end

return T
