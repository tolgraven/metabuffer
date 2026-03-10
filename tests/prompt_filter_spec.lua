local T = MiniTest.new_set()

local function wait_for(pred, timeout_ms)
  local ok = vim.wait(timeout_ms or 2000, pred, 20)
  MiniTest.expect.equality(ok, true)
end

local function start_session()
  vim.cmd("edit README.md")
  local source_buf = vim.api.nvim_get_current_buf()
  local router = require("metabuffer.router")
  router.entry_start("", true)
  local session = router["active-by-source"][source_buf]
  MiniTest.expect.equality(type(session), "table")
  return router, session
end

local function finish_session(router, session)
  router.finish("cancel", session["prompt-buf"])
  vim.cmd("enew")
end

local function set_prompt(session, text)
  vim.api.nvim_buf_set_lines(session["prompt-buf"], 0, -1, false, { text })
end

local function query_text(session)
  return table.concat(session.meta["query-lines"] or {}, "\n")
end

T["prompt text updates are applied for short and medium tokens"] = function()
  local router, session = start_session()

  set_prompt(session, "lu")
  wait_for(function()
    return query_text(session) == "lu"
  end, 2500)
  local lu_hits = #(session.meta.buf.indices or {})

  set_prompt(session, "lua")
  wait_for(function()
    return query_text(session) == "lua"
  end, 2500)
  local lua_hits = #(session.meta.buf.indices or {})

  MiniTest.expect.equality(lu_hits >= lua_hits, true)
  finish_session(router, session)
end

T["meta and metam both trigger filtering"] = function()
  local router, session = start_session()

  set_prompt(session, "meta")
  wait_for(function()
    return query_text(session) == "meta"
  end, 2500)
  local meta_hits = #(session.meta.buf.indices or {})

  set_prompt(session, "metam")
  wait_for(function()
    return query_text(session) == "metam"
  end, 2500)
  local metam_hits = #(session.meta.buf.indices or {})

  MiniTest.expect.equality(meta_hits >= metam_hits, true)
  finish_session(router, session)
end

T["deleting broadens hit set"] = function()
  local router, session = start_session()

  set_prompt(session, "tol")
  wait_for(function()
    return query_text(session) == "tol"
  end, 2500)
  local tol_hits = #(session.meta.buf.indices or {})

  set_prompt(session, "to")
  wait_for(function()
    return query_text(session) == "to"
  end, 2500)
  local to_hits = #(session.meta.buf.indices or {})

  MiniTest.expect.equality(to_hits >= tol_hits, true)
  finish_session(router, session)
end

return T
