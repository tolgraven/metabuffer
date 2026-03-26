#!/usr/bin/env bash
set -euo pipefail
umask 022

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"
CACHE_DIR="$ROOT_DIR/.cache/metabuffer-tests"
FAIL_LIST_FILE="$CACHE_DIR/failed-files.txt"
mkdir -p "$CACHE_DIR"

if ! command -v nvim >/dev/null 2>&1; then
  echo "error: nvim not found in PATH" >&2
  exit 127
fi

cpu_count() {
  if command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN 2>/dev/null && return
  fi
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu 2>/dev/null && return
  fi
  echo 4
}

default_jobs() {
  local cpu_n="$1"
  local file_n="$2"
  local oversubscribe="${TEST_JOBS_MULTIPLIER:-2}"
  local extra_jobs="${TEST_JOBS_EXTRA:-0}"
  local jobs

  if ! [[ "$oversubscribe" =~ ^[0-9]+$ ]] || (( oversubscribe < 1 )); then
    oversubscribe=2
  fi
  if ! [[ "$extra_jobs" =~ ^[0-9]+$ ]] || (( extra_jobs < 0 )); then
    extra_jobs=0
  fi

  local default_max_jobs=$((cpu_n * oversubscribe))
  local max_jobs="${TEST_MAX_JOBS:-$default_max_jobs}"
  if ! [[ "$max_jobs" =~ ^[0-9]+$ ]] || (( max_jobs < 1 )); then
    max_jobs="$file_n"
  fi

  jobs=$(((cpu_n * oversubscribe) + extra_jobs))
  if (( jobs < 1 )); then
    jobs=1
  fi
  if (( jobs > max_jobs )); then
    jobs="$max_jobs"
  fi
  if (( jobs > file_n )); then
    jobs="$file_n"
  fi
  echo "$jobs"
}

TEST_FILES=()
while IFS= read -r file; do
  TEST_FILES+=("$file")
done < <(rg --files tests | rg '^tests/(screen|unit)(/.+)?/test_.*\.lua$' | sort)
while IFS= read -r file; do
  TEST_FILES+=("$file")
done < <(rg --files tests/smoke | sort)
# profile tests discovered separately; appended later when --profile is active

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "error: no test files matched tests/**/test_*.lua" >&2
  exit 2
fi

if [[ "${TEST_FAILED_ONLY:-0}" == "1" ]]; then
  if [[ ! -s "$FAIL_LIST_FILE" ]]; then
    echo "[mini-runner] no failed-tests list found at $FAIL_LIST_FILE; running full suite"
  else
    map_failed=()
    while IFS= read -r file; do
      [[ -n "$file" ]] && map_failed+=("$file")
    done < "$FAIL_LIST_FILE"
    if [[ ${#map_failed[@]} -eq 0 ]]; then
      echo "[mini-runner] failed-tests list is empty; running full suite"
    else
      TEST_FILES=("${map_failed[@]}")
    fi
  fi
fi

FILTERS=()
PROFILE_MODE=0
VERBOSE=0
SHOW_TIMINGS=0
SKIP_SMOKE=0
INCLUDE_ANIMATION=0
TEST_FILE_TIMEOUT_MS="${TEST_FILE_TIMEOUT_MS:-18000}"
if [[ "$TEST_FILE_TIMEOUT_MS" =~ ^[0-9]+$ ]]; then
  :
else
  echo "error: TEST_FILE_TIMEOUT_MS must be an integer in milliseconds (got '$TEST_FILE_TIMEOUT_MS')" >&2
  exit 2
fi
POSITIONAL=()
for arg in "$@"; do
  if [[ "$arg" == "--profile" ]]; then
    PROFILE_MODE=1
  elif [[ "$arg" == "--verbose" ]]; then
    VERBOSE=1
  elif [[ "$arg" == "--no-smoke" ]]; then
    SKIP_SMOKE=1
  elif [[ "$arg" == "--animation" ]]; then
    INCLUDE_ANIMATION=1
  elif [[ "$arg" == "--timings" ]]; then
    SHOW_TIMINGS=1
  else
    POSITIONAL+=("$arg")
  fi
done
if (( ${#POSITIONAL[@]} > 0 )); then
  FILTERS=("${POSITIONAL[@]}")
fi

if (( PROFILE_MODE == 1 )); then
  while IFS= read -r file; do
    TEST_FILES+=("$file")
  done < <(rg --files tests/profile | sort)
fi

SMOKE_TESTS=(
  "tests/smoke/test_smoke_plugin_source.lua"
  "tests/smoke/test_smoke_reload_compile.lua"
  "tests/smoke/test_smoke_plain_headless_launch.lua"
  "tests/smoke/test_smoke_plain_launch.lua"
  "tests/smoke/test_smoke_project_headless_launch.lua"
  "tests/smoke/test_smoke_project_plain_launch.lua"
)

if [[ -n "${TEST_ONLY:-}" ]]; then
  echo "[mini-runner] note: TEST_ONLY is deprecated; pass selectors as script args instead"
  IFS=',' read -r -a LEGACY_FILTERS <<< "${TEST_ONLY}"
  if (( ${#LEGACY_FILTERS[@]} > 0 )); then
    for f in "${LEGACY_FILTERS[@]}"; do
      [[ -n "$f" ]] && FILTERS+=("$f")
    done
  fi
fi

if [[ ${#FILTERS[@]} -gt 0 ]]; then
  for f in "${FILTERS[@]}"; do
    [[ -z "$f" ]] && continue
    if [[ "$f" == tests/profile/* ]] && [[ -f "$f" ]]; then
      TEST_FILES+=("$f")
    fi
  done
  FILTERED=()
  for file in "${TEST_FILES[@]}"; do
    for f in "${FILTERS[@]}"; do
      [[ -z "$f" ]] && continue
      if [[ -d "tests/$f" ]] && [[ "$file" == tests/$f/* ]]; then
        FILTERED+=("$file")
        break
      fi
      if [[ -d "tests/screen/$f" ]] && [[ "$file" == tests/screen/$f/* ]]; then
        FILTERED+=("$file")
        break
      fi
      if [[ -d "tests/unit/$f" ]] && [[ "$file" == tests/unit/$f/* ]]; then
        FILTERED+=("$file")
        break
      fi
      if [[ "$file" == "$f" ]]; then
        FILTERED+=("$file")
        break
      fi
      if [[ "$file" =~ $f ]]; then
        FILTERED+=("$file")
        break
      fi
    done
  done
  TEST_FILES=("${FILTERED[@]}")
fi

# Exclude animation tests unless --animation is passed.
if (( INCLUDE_ANIMATION == 0 )); then
  NON_ANIM=()
  for file in "${TEST_FILES[@]}"; do
    if [[ "$file" != tests/screen/animation/* ]]; then
      NON_ANIM+=("$file")
    fi
  done
  TEST_FILES=("${NON_ANIM[@]}")
fi

# Auto-skip smoke tests when no screen tests are selected (unit-only runs).
if (( SKIP_SMOKE == 0 )); then
  _has_screen=0
  for _f in "${TEST_FILES[@]}"; do
    if [[ "$_f" == tests/screen/* ]]; then
      _has_screen=1
      break
    fi
  done
  if (( _has_screen == 0 )); then
    SKIP_SMOKE=1
  fi
fi

ORDERED_TEST_FILES=()
if (( SKIP_SMOKE == 0 )); then
  for smoke in "${SMOKE_TESTS[@]}"; do
    ORDERED_TEST_FILES+=("$smoke")
  done
fi
for file in "${TEST_FILES[@]}"; do
  skip=0
  if (( SKIP_SMOKE == 0 )); then
    for smoke in "${SMOKE_TESTS[@]}"; do
      if [[ "$file" == "$smoke" ]]; then
        skip=1
        break
      fi
    done
  fi
  if (( skip == 0 )); then
    ORDERED_TEST_FILES+=("$file")
  fi
done
# Longest-first scheduling: known-slow tests go first so xargs -P streams them
# into early worker slots.  Fast tests backfill as slots free up.
# Entries are substring-matched against file paths (no glob, just contains).
# Only reorders non-smoke entries; smoke prefix is preserved.
SLOW_PREFIXES=(
  "test_screen_edit_propagation"
  "test_screen_edit_project_insert_writeback"
  "test_screen_context_expansion_fn"
)
SMOKE_PREFIX_FILES=()
PRIORITY_FILES=()
REST_FILES=()
for file in "${ORDERED_TEST_FILES[@]}"; do
  is_smoke=0
  if (( SKIP_SMOKE == 0 )); then
    for smoke in "${SMOKE_TESTS[@]}"; do
      if [[ "$file" == "$smoke" ]]; then
        is_smoke=1
        break
      fi
    done
  fi
  if (( is_smoke )); then
    SMOKE_PREFIX_FILES+=("$file")
    continue
  fi
  is_slow=0
  for prefix in "${SLOW_PREFIXES[@]}"; do
    if [[ "$file" == *"$prefix"* ]]; then
      is_slow=1
      break
    fi
  done
  if (( is_slow )); then
    PRIORITY_FILES+=("$file")
  else
    REST_FILES+=("$file")
  fi
done
TEST_FILES=("${SMOKE_PREFIX_FILES[@]}" "${PRIORITY_FILES[@]}" "${REST_FILES[@]}")

# Batch unit tests: combine into pipe-separated groups to reduce nvim starts.
# Screen tests are NOT batched (each needs its own child nvim lifecycle).
UNIT_BATCH_SIZE=${TEST_UNIT_BATCH_SIZE:-10}
BATCHED_TEST_FILES=()
unit_batch=""
unit_batch_count=0

for file in "${TEST_FILES[@]}"; do
  if [[ "$file" == tests/unit/* ]]; then
    if [[ -n "$unit_batch" ]]; then
      unit_batch="${unit_batch}|${file}"
    else
      unit_batch="$file"
    fi
    unit_batch_count=$((unit_batch_count + 1))
    if (( unit_batch_count >= UNIT_BATCH_SIZE )); then
      BATCHED_TEST_FILES+=("$unit_batch")
      unit_batch=""
      unit_batch_count=0
    fi
  else
    BATCHED_TEST_FILES+=("$file")
  fi
done
if [[ -n "$unit_batch" ]]; then
  BATCHED_TEST_FILES+=("$unit_batch")
fi
TEST_FILES=("${BATCHED_TEST_FILES[@]}")

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "error: no tests selected after filtering" >&2
  exit 2
fi

CPU_N=$(cpu_count)
DEFAULT_JOBS=$(default_jobs "$CPU_N" "${#TEST_FILES[@]}")

JOBS=${TEST_JOBS:-$DEFAULT_JOBS}
if [[ "$JOBS" =~ ^[0-9]+$ ]]; then
  :
else
  echo "error: TEST_JOBS must be an integer (got '$JOBS')" >&2
  exit 2
fi
if (( JOBS < 1 )); then
  JOBS=1
fi
if (( JOBS > ${#TEST_FILES[@]} )); then
  JOBS=${#TEST_FILES[@]}
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/metabuffer-mini.XXXXXX")
chmod 755 "$TMP_DIR" 2>/dev/null || true
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
PROFILE_DIR=""
if (( PROFILE_MODE == 1 )); then
  PROFILE_DIR="${TEST_PROFILE_DIR:-/tmp/metabuffer-profile-$$-$(date +%s)}"
  mkdir -p "$PROFILE_DIR"
fi
FIXTURE_SRC="$ROOT_DIR/tests/fixture"
if [[ -d "$FIXTURE_SRC" ]]; then
  META_TEST_FIXTURE_ROOT="$TMP_DIR/fixture"
  cp -R "$FIXTURE_SRC" "$META_TEST_FIXTURE_ROOT"
  chmod -R 755 "$META_TEST_FIXTURE_ROOT" 2>/dev/null || true
  cat "$META_TEST_FIXTURE_ROOT"/**/* >/dev/null 2>&1 || true
  export META_TEST_FIXTURE_ROOT
fi

# Pre-create temp project source for make_temp_project() callers.
# Tests cp -R from this instead of creating files via child RPC.
TEMP_PROJECT_SRC="$ROOT_DIR/tests/temp_project"
if [[ -d "$TEMP_PROJECT_SRC" ]]; then
  META_TEST_TEMP_PROJECT_SRC="$TMP_DIR/temp_project_src"
  cp -R "$TEMP_PROJECT_SRC" "$META_TEST_TEMP_PROJECT_SRC"
  chmod -R 755 "$META_TEST_TEMP_PROJECT_SRC" 2>/dev/null || true
  cat "$META_TEST_TEMP_PROJECT_SRC"/**/* >/dev/null 2>&1 || true
  export META_TEST_TEMP_PROJECT_SRC
fi

echo "[mini-runner] tmp dir: $TMP_DIR"

TOTAL_START_MS=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)

echo "[mini-runner] running ${#TEST_FILES[@]} files with ${JOBS} parallel worker(s)"
if (( SKIP_SMOKE == 0 )); then
  echo "[mini-runner] startup smoke tests first: ${SMOKE_TESTS[*]}"
else
  echo "[mini-runner] startup smoke tests skipped"
fi
if (( PROFILE_MODE == 1 )); then
  echo "[mini-runner] profiling enabled"
  echo "[mini-runner] profile dir: $PROFILE_DIR"
fi

run_worker() {
  local idx="$1"
  local file="$2"
  local tmp_dir="$3"

  local base
  base=$(basename "$file")
  local log="$tmp_dir/$idx.log"
  local status="$tmp_dir/$idx.status"
  local elapsed_ms_file="$tmp_dir/$idx.elapsed_ms"
  local profile="$PROFILE_DIR/$idx-$(basename "$file" .lua).profile.log"
  local appname="metabuffer-mini-${idx}-$$"
  local xdg_root="$tmp_dir/xdg-$idx"
  local timeout_flag="$tmp_dir/$idx.timeout"
  local timeout_s=$(((TEST_FILE_TIMEOUT_MS + 999) / 1000))
  local worker_ui_animations="${TEST_UI_ANIMATIONS:-0}"

  for smoke in "${SMOKE_TESTS[@]}"; do
    if [[ "$file" == "$smoke" ]]; then
      worker_ui_animations=1
      break
    fi
  done

  local file_start_ms
  file_start_ms=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)
  mkdir -p "$xdg_root/data" "$xdg_root/state" "$xdg_root/cache" "$xdg_root/config"
  if (( PROFILE_MODE == 1 )); then
    : > "$profile"
  fi
  : > "$log"
  rm -f "$timeout_flag"

  local rc=0
  local -a nvim_cmd=(
    nvim --headless -u tests/minimal_init.lua -n -i NONE
    -c "lua local ok, err = pcall(function() local files={}; for p in vim.env.TEST_FILE:gmatch('[^|]+') do files[#files+1]=p end; MiniTest.run({collect={find_files=function() return files end}, execute={stop_on_error=false, reporter=MiniTest.gen_reporter.stdout({group_depth=1})}}) end); if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd('cquit 1'); end"
    -c "lua vim.wait(600000, function() return not MiniTest.is_executing() end, 20); local fails = 0; for _, c in ipairs(MiniTest.current.all_cases or {}) do local s = c.exec and c.exec.state or ''; if s == 'Fail' or s == 'Fail with notes' then fails = fails + 1 end end; if fails > 0 then vim.cmd('cquit 1'); end"
    -c "qa!"
  )
  if (( VERBOSE == 1 )); then
    {
      echo "[worker $idx] FILE START $file"
      if (( PROFILE_MODE == 1 )); then
        echo "[worker $idx] PROFILE FILE $profile"
      fi
    } >> "$log"
  fi

  if command -v setsid >/dev/null 2>&1; then
    TEST_FILE="$file" TEST_PROFILE="$PROFILE_MODE" TEST_PROFILE_PATH="$profile" TEST_WORKER_INDEX="$idx" TEST_UI_ANIMATIONS="$worker_ui_animations" NVIM_APPNAME="$appname" \
      META_TEST_FIXTURE_ROOT="${META_TEST_FIXTURE_ROOT:-}" \
      TMPDIR="/tmp" \
      XDG_DATA_HOME="$xdg_root/data" \
      XDG_STATE_HOME="$xdg_root/state" \
      XDG_CACHE_HOME="$xdg_root/cache" \
      XDG_CONFIG_HOME="$xdg_root/config" \
      setsid "${nvim_cmd[@]}" >"$log" 2>&1 &
  else
    TEST_FILE="$file" TEST_PROFILE="$PROFILE_MODE" TEST_PROFILE_PATH="$profile" TEST_WORKER_INDEX="$idx" TEST_UI_ANIMATIONS="$worker_ui_animations" NVIM_APPNAME="$appname" \
      META_TEST_FIXTURE_ROOT="${META_TEST_FIXTURE_ROOT:-}" \
      TMPDIR="/tmp" \
      XDG_DATA_HOME="$xdg_root/data" \
      XDG_STATE_HOME="$xdg_root/state" \
      XDG_CACHE_HOME="$xdg_root/cache" \
      XDG_CONFIG_HOME="$xdg_root/config" \
      "${nvim_cmd[@]}" >"$log" 2>&1 &
  fi
  local test_pid=$!

  (
    sleep "$timeout_s" &
    local sl=$!
    trap 'kill $sl 2>/dev/null; exit 0' TERM
    wait "$sl" 2>/dev/null || exit 0
    if kill -0 "$test_pid" 2>/dev/null; then
      echo "[mini-runner] TIMEOUT file=$file timeout_ms=$TEST_FILE_TIMEOUT_MS" >> "$log"
      : > "$timeout_flag"
      kill -TERM -- "-$test_pid" 2>/dev/null || kill -TERM "$test_pid" 2>/dev/null || true
      sleep 2
      kill -KILL -- "-$test_pid" 2>/dev/null || kill -KILL "$test_pid" 2>/dev/null || true
    fi
  ) &
  local watchdog_pid=$!

  wait "$test_pid" || rc=$?
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  if [[ -f "$timeout_flag" ]]; then
    rc=124
  fi

  if [[ "$rc" == "0" ]] && grep -F -q \
    -e 'stack traceback' \
    -e 'vim.schedule callback:' \
    -e 'Lua :command callback:' \
    -e 'torn down after error' \
    -e '_core/editor.lua' \
    -e 'E5108:' \
    -e 'Error in function ' \
    "$log"; then
    echo "[mini-runner] detected runtime error pattern in worker log" >> "$log"
    rc=1
  fi

  if (( VERBOSE == 1 )); then
    sed -u "s/^/[w${idx}:${base}] /" "$log"
  fi

  # Always print output for failed workers (non-verbose mode gets it in summary)
  if [[ "$rc" != "0" ]] && (( VERBOSE == 0 )); then
    {
      echo ""
      echo "=== FAIL worker $idx: $file (rc=$rc) ==="
      cat "$log"
      echo "=== END worker $idx ==="
      echo ""
    } >> "$tmp_dir/$idx.fail_output"
  fi

  local file_end_ms
  file_end_ms=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)
  local file_dt_ms=$((file_end_ms - file_start_ms))

  if (( PROFILE_MODE == 1 )) && [[ -s "$profile" ]]; then
    if (( VERBOSE == 1 )); then
      sed -u "s/^/[w${idx}:${base}] /" "$profile" | tee -a "$log"
    else
      echo "[mini-runner] PROFILE $file | $profile" >> "$log"
    fi
  fi

  echo "$file_dt_ms" > "$elapsed_ms_file"
  if (( VERBOSE == 1 )); then
    echo "[worker $idx] FILE END $file | rc=$rc | ${file_dt_ms}ms" | sed -u "s/^/[w${idx}:${base}] /" | tee -a "$log"
  fi
  echo "$rc" > "$status"
  return 0
}

export -f run_worker
export ROOT_DIR
export PROFILE_MODE
export PROFILE_DIR
export TEST_FILE_TIMEOUT_MS
export META_TEST_FIXTURE_ROOT
export META_TEST_TEMP_PROJECT_SRC

SMOKE_COUNT=0
if (( SKIP_SMOKE == 0 )); then
  SMOKE_COUNT=${#SMOKE_TESTS[@]}
  # Run smoke tests in parallel for faster startup gate.
  for i in "${!SMOKE_TESTS[@]}"; do
    idx=$((i + 1))
    run_worker "$idx" "${SMOKE_TESTS[$i]}" "$TMP_DIR" &
  done
  wait
  # Check all smoke results; abort on any failure.
  for i in "${!SMOKE_TESTS[@]}"; do
    idx=$((i + 1))
    smoke="${SMOKE_TESTS[$i]}"
    smoke_status_file="$TMP_DIR/$idx.status"
    smoke_rc=99
    if [[ -f "$smoke_status_file" ]]; then
      smoke_rc=$(cat "$smoke_status_file")
    fi
    if [[ "$smoke_rc" != "0" ]]; then
      : > "$FAIL_LIST_FILE"
      echo "$smoke" >> "$FAIL_LIST_FILE"
      smoke_log="$TMP_DIR/$idx.log"
      echo ""
      echo "=== SMOKE FAIL: $smoke (rc=$smoke_rc) ==="
      if [[ -s "$smoke_log" ]]; then
        cat "$smoke_log"
      fi
      echo "=== END SMOKE FAIL ==="
      echo ""
      TOTAL_END_MS=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)
      TOTAL_DT_MS=$((TOTAL_END_MS - TOTAL_START_MS))
      echo "[mini-runner] FAIL file=$smoke rc=$smoke_rc"
      echo "[mini-runner] TOTAL ${#TEST_FILES[@]} file(s) | failed=1 | elapsed=${TOTAL_DT_MS}ms"
      echo "[mini-runner] aborted after startup smoke failure"
      echo "[mini-runner] failed list path:  $FAIL_LIST_FILE"
      exit 1
    fi
  done
fi

if (( ${#TEST_FILES[@]} > SMOKE_COUNT )); then
  : > "$TMP_DIR/indexed.tsv"
  for i in "${!TEST_FILES[@]}"; do
    idx=$((i + 1))
    if (( idx > SMOKE_COUNT )); then
      printf '%s\t%s\n' "$idx" "${TEST_FILES[$i]}" >> "$TMP_DIR/indexed.tsv"
    fi
  done

  xargs -P "$JOBS" -n3 bash -c 'run_worker "$1" "$2" "$3"' _ < <(
    awk -F '\t' '{print $1" "$2" '"$TMP_DIR"'"}' "$TMP_DIR/indexed.tsv"
  )
fi

FAIL_FILES=0
: > "$FAIL_LIST_FILE"
for i in "${!TEST_FILES[@]}"; do
  idx=$((i + 1))
  file="${TEST_FILES[$i]}"
  status_file="$TMP_DIR/$idx.status"
  rc=99
  if [[ -f "$status_file" ]]; then
    rc=$(cat "$status_file")
  fi
  if [[ "$rc" != "0" ]]; then
    echo "[mini-runner] FAIL file=$file rc=$rc"
    fail_output="$TMP_DIR/$idx.fail_output"
    log_file="$TMP_DIR/$idx.log"
    if [[ -s "$fail_output" ]]; then
      cat "$fail_output"
    elif [[ -s "$log_file" ]]; then
      echo ""
      echo "=== FAIL worker $idx: $file (rc=$rc) ==="
      cat "$log_file"
      echo "=== END worker $idx ==="
      echo ""
    fi
    IFS='|' read -ra _batch_files <<< "$file"
    for _bf in "${_batch_files[@]}"; do
      echo "$_bf" >> "$FAIL_LIST_FILE"
    done
    FAIL_FILES=$((FAIL_FILES + 1))
  fi
done

TOTAL_END_MS=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)
TOTAL_DT_MS=$((TOTAL_END_MS - TOTAL_START_MS))

TIMING_ROWS=()
for i in "${!TEST_FILES[@]}"; do
  idx=$((i + 1))
  file="${TEST_FILES[$i]}"
  elapsed_ms_path="$TMP_DIR/$idx.elapsed_ms"
  if [[ -f "$elapsed_ms_path" ]]; then
    elapsed_ms=$(cat "$elapsed_ms_path")
    TIMING_ROWS+=("${elapsed_ms}"$'\t'"$file")
  fi
done

if (( (VERBOSE == 1 || SHOW_TIMINGS == 1) )) && (( ${#TIMING_ROWS[@]} > 0 )); then
  echo "[mini-runner] FILE TIMINGS"
  rank=0
  while IFS=$'\t' read -r elapsed_ms file; do
    rank=$((rank + 1))
    printf '[mini-runner]   %02d. %6sms | %s\n' "$rank" "$elapsed_ms" "$file"
  done < <(printf '%s\n' "${TIMING_ROWS[@]}" | sort -rn -k1,1)
fi

ACTUAL_FILE_COUNT=0
for entry in "${TEST_FILES[@]}"; do
  IFS='|' read -ra _parts <<< "$entry"
  ACTUAL_FILE_COUNT=$((ACTUAL_FILE_COUNT + ${#_parts[@]}))
done

echo "[mini-runner] TOTAL ${ACTUAL_FILE_COUNT} file(s) (${#TEST_FILES[@]} worker(s)) | failed=$FAIL_FILES | elapsed=${TOTAL_DT_MS}ms"

if (( FAIL_FILES > 0 )); then
  echo "[mini-runner] rerun failed only: TEST_FAILED_ONLY=1 ./scripts/test-mini.sh"
  echo "[mini-runner] rerun one file:    ./scripts/test-mini.sh tests/unit/test_query_unit.lua"
  echo "[mini-runner] failed list path:  $FAIL_LIST_FILE"
  exit 1
fi
