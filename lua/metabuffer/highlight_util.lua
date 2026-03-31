-- [nfnl] fnl/metabuffer/highlight_util.fnl
local M = {}
M["hl-rendered-fg"] = function(hl)
  if not hl then
    return nil
  else
    if hl.reverse then
      return (hl.bg or hl.fg)
    else
      return hl.fg
    end
  end
end
M["hl-rendered-bg"] = function(hl)
  if not hl then
    return nil
  else
    if hl.reverse then
      return (hl.fg or hl.bg)
    else
      return hl.bg
    end
  end
end
M["darken-rgb"] = function(n, factor)
  if not n then
    return nil
  else
    local r = math.floor((n / 65536))
    local g = math.floor(((n / 256) % 256))
    local b = (n % 256)
    local f = math.max(0, math.min(factor, 1))
    local dr = math.max(0, math.min(255, math.floor((r * (1 - f)))))
    local dg = math.max(0, math.min(255, math.floor((g * (1 - f)))))
    local db = math.max(0, math.min(255, math.floor((b * (1 - f)))))
    return ((dr * 65536) + (dg * 256) + db)
  end
end
M["brighten-rgb"] = function(n, factor)
  if not n then
    return nil
  else
    local r = math.floor((n / 65536))
    local g = math.floor(((n / 256) % 256))
    local b = (n % 256)
    local f = math.max(0, math.min(factor, 1))
    local br = math.max(0, math.min(255, math.floor((r + ((255 - r) * f)))))
    local bg = math.max(0, math.min(255, math.floor((g + ((255 - g) * f)))))
    local bb = math.max(0, math.min(255, math.floor((b + ((255 - b) * f)))))
    return ((br * 65536) + (bg * 256) + bb)
  end
end
M["copy-highlight-with-bg"] = function(group, bg)
  local opts = {default = true, cterm = {reverse = false}, reverse = false}
  local ok,hl = pcall(vim.api.nvim_get_hl, 0, {name = group, link = false})
  if (ok and (type(hl) == "table")) then
    if M["hl-rendered-fg"](hl) then
      opts["fg"] = M["hl-rendered-fg"](hl)
    else
    end
    if hl.ctermfg then
      opts["ctermfg"] = hl.ctermfg
    else
    end
    if hl.bold then
      opts["bold"] = hl.bold
    else
    end
  else
  end
  opts["bg"] = bg
  return opts
end
return M
