#!/usr/bin/env sh
set -eu

VERBOSE=0
if [ "${1:-}" = "--verbose" ]; then
  VERBOSE=1
  shift
fi

if [ "$#" -gt 0 ]; then
  echo "usage: $0 [--verbose]" >&2
  exit 1
fi

if ! command -v nvim >/dev/null 2>&1; then
  echo "neovim not found" >&2
  exit 1
fi

mkdir -p lua plugin
tmp_dir="${TMPDIR:-"/tmp"}"

compile_script="$(mktemp $tmp_dir/metabuffer-compile.lua.XXXXXX)"
cat >"$compile_script" <<'EOF'
local verbose = (os.getenv("META_COMPILE_VERBOSE") == "1")

local function read_untrusted(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

if vim.secure and vim.secure.read then
  vim.secure.read = read_untrusted
end

if not verbose then
  local old_notify = vim.api.nvim_notify
  vim.api.nvim_notify = function(msg, level, opts)
    if level >= vim.log.levels.ERROR then
      return old_notify(msg, level, opts)
    end
  end
end

local function result_has_errors(results)
  if type(results) ~= "table" then
    return false
  end
  for _, item in ipairs(results) do
    if type(item) == "table" and item.status and item.status ~= "ok" then
      return true
    end
  end
  return false
end

local function emit_errors(results)
  if type(results) ~= "table" then
    return
  end
  for _, item in ipairs(results) do
    if type(item) == "table" and item.status and item.status ~= "ok" then
      vim.api.nvim_err_writeln(vim.inspect(item))
    end
  end
end

local ok, results = pcall(function()
  return require("metabuffer.nfnl.api")["compile-all-files"](vim.fn.getcwd())
end)

if not ok then
  vim.api.nvim_err_writeln(results)
  vim.cmd("cquit 1")
  return
end

if result_has_errors(results) then
  emit_errors(results)
  vim.cmd("cquit 1")
  return
end

vim.cmd("qa")
EOF

run_nvim_compile() {
  if [ "$VERBOSE" -eq 1 ]; then
    META_COMPILE_VERBOSE=1 \
    NVIM_LOG_FILE="${NVIM_LOG_FILE:-/dev/null}" \
    nvim --headless -u NONE -n \
      -i NONE \
      --cmd "set runtimepath^=." \
      -l "$compile_script"
  else
    compile_log="$(mktemp $tmp_dir/metabuffer-compile.log.XXXXXX)"
    if ! META_COMPILE_VERBOSE=0 \
      NVIM_LOG_FILE="${NVIM_LOG_FILE:-/dev/null}" \
      nvim --headless -u NONE -n \
        -i NONE \
        --cmd "set runtimepath^=." \
        -l "$compile_script" >"$compile_log" 2>&1; then
      cat "$compile_log" >&2
      rm -f "$compile_log"
      rm -f "$compile_script"
      exit 1
    fi
    rm -f "$compile_log"
  fi
}

run_luals_check() {
  check_dir="$1"
  if [ "$VERBOSE" -eq 1 ]; then
    lua-language-server \
      --check="$check_dir" \
      --checklevel=Error \
      --check_format=pretty \
      --configpath="$CONFIG_PATH" \
      --logpath=.cache/luals/log \
      --metapath=.cache/luals/meta
  else
    luals_log="$(mktemp $tmp_dir/metabuffer-luals.log.XXXXXX)"
    if ! lua-language-server \
      --check="$check_dir" \
      --checklevel=Error \
      --check_format=pretty \
      --configpath="$CONFIG_PATH" \
      --logpath=.cache/luals/log \
      --metapath=.cache/luals/meta >"$luals_log" 2>&1; then
      cat "$luals_log" >&2
      rm -f "$luals_log"
      rm -f "$compile_script"
      exit 1
    fi
    rm -f "$luals_log"
  fi
}

# if command -v deps >/dev/null 2>&1; then
#   eval "$(deps --path)" # ensured deps are pulled (from deps.fnl)
# fi
run_nvim_compile

if command -v lua-language-server >/dev/null 2>&1; then
  CONFIG_PATH="$(pwd)/.luarc.json"
  mkdir -p .cache/luals/log .cache/luals/meta
  run_luals_check lua
  run_luals_check plugin
fi

rm -f "$compile_script"
echo "Compile successful."
