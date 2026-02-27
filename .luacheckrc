std = "lua51"
globals = {"vim"}

ignore = {
  "212", -- unused argument (generated wrappers)
  "213", -- unused loop variable (generated loops)
  "631", -- line too long (generated code)
  "542", -- empty branches from generated conditionals
  "541", -- empty do..end from generated code
  "581", -- stylistic boolean simplification
  "311", -- overwritten before use (generated temps)
  "231", -- never accessed variable (generated temps)
  "211", -- unused variable (generated temps)
  "431", -- shadowing upvalue (generated code)
  "432", -- shadowing argument (generated code)
  "112", -- mutating global vim via fields
}

files["lua/metabuffer/nfnl/**"] = {
  ignore = true,
}
