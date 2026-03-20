#!/usr/bin/env bash
set -euo pipefail

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
  local default_max_jobs=$((cpu_n * 2))
  local max_jobs="${TEST_MAX_JOBS:-$default_max_jobs}"
  local jobs

  if [[ "$oversubscribe" =~ ^[0-9]+$ ]]; then
    :
  else
    oversubscribe=2
  fi
  if (( oversubscribe < 1 )); then
    oversubscribe=1
  fi
  if [[ "$extra_jobs" =~ ^[0-9]+$ ]]; then
    :
  else
    extra_jobs=2
  fi
  if (( extra_jobs < 0 )); then
    extra_jobs=0
  fi
  if [[ "$max_jobs" =~ ^[0-9]+$ ]]; then
    :
  else
    max_jobs="$file_n"
  fi
  if (( max_jobs < 1 )); then
    max_jobs=1
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
done < <(rg --files tests | rg '^tests/.*/test_.*\.lua$' | sort)

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
  else
    POSITIONAL+=("$arg")
  fi
done
if (( ${#POSITIONAL[@]} > 0 )); then
  FILTERS=("${POSITIONAL[@]}")
fi

if [[ -n "${TEST_ONLY:-}" ]]; then
  echo "[mini-runner] note: TEST_ONLY is deprecated; pass selectors as script args instead"
  IFS=',' read -r -a LEGACY_FILTERS <<< "${TEST_ONLY}"
  for f in "${LEGACY_FILTERS[@]}"; do
    [[ -n "$f" ]] && FILTERS+=("$f")
  done
fi

if [[ ${#FILTERS[@]} -gt 0 ]]; then
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
PROFILE_DIR=""
if (( PROFILE_MODE == 1 )); then
  PROFILE_DIR="${TEST_PROFILE_DIR:-/tmp/metabuffer-profile-$$-$(date +%s)}"
  mkdir -p "$PROFILE_DIR"
fi
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

TOTAL_START_MS=$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)

echo "[mini-runner] running ${#TEST_FILES[@]} files with ${JOBS} parallel worker(s)"
if (( PROFILE_MODE == 1 )); then
  echo "[mini-runner] profiling enabled"
  echo "[mini-runner] profile dir: $PROFILE_DIR"
fi

for i in "${!TEST_FILES[@]}"; do
  idx=$((i + 1))
  printf '%s\t%s\n' "$idx" "${TEST_FILES[$i]}" >> "$TMP_DIR/indexed.tsv"
done

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
  if (( VERBOSE == 1 )); then
    {
      echo "[worker $idx] FILE START $file"
      if (( PROFILE_MODE == 1 )); then
        echo "[worker $idx] PROFILE FILE $profile"
      fi
    } >> "$log"
  fi

  TEST_FILE="$file" TEST_PROFILE="$PROFILE_MODE" TEST_PROFILE_PATH="$profile" TEST_WORKER_INDEX="$idx" NVIM_APPNAME="$appname" \
    TMPDIR="/tmp" \
    XDG_DATA_HOME="$xdg_root/data" \
    XDG_STATE_HOME="$xdg_root/state" \
    XDG_CACHE_HOME="$xdg_root/cache" \
    XDG_CONFIG_HOME="$xdg_root/config" \
    nvim --headless -u tests/minimal_init.lua -n -i NONE \
    -c "lua local ok, err = pcall(function() MiniTest.run({collect={find_files=function() return {vim.env.TEST_FILE} end}, execute={stop_on_error=false, reporter=MiniTest.gen_reporter.stdout({group_depth=1})}}) end); if not ok then vim.api.nvim_err_writeln(tostring(err)); vim.cmd('cquit 1'); end" \
    -c "lua vim.wait(600000, function() return not MiniTest.is_executing() end, 20); local fails = 0; for _, c in ipairs(MiniTest.current.all_cases or {}) do local s = c.exec and c.exec.state or ''; if s == 'Fail' or s == 'Fail with notes' then fails = fails + 1 end end; if fails > 0 then vim.cmd('cquit 1'); end" \
    -c "qa!" >"$log" 2>&1 &
  local test_pid=$!

  (
    sleep "$timeout_s"
    if kill -0 "$test_pid" 2>/dev/null; then
      echo "[mini-runner] TIMEOUT file=$file timeout_ms=$TEST_FILE_TIMEOUT_MS" >> "$log"
      : > "$timeout_flag"
      kill -TERM "$test_pid" 2>/dev/null || true
      sleep 2
      kill -KILL "$test_pid" 2>/dev/null || true
    fi
  ) &
  local watchdog_pid=$!

  if ! wait "$test_pid"; then
    rc=$?
  fi
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  if [[ -f "$timeout_flag" ]]; then
    rc=124
  fi

  if (( VERBOSE == 1 )); then
    sed -u "s/^/[w${idx}:${base}] /" "$log"
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

xargs -P "$JOBS" -n3 bash -c 'run_worker "$1" "$2" "$3"' _ < <(
  awk -F '\t' '{print $1" "$2" '"$TMP_DIR"'"}' "$TMP_DIR/indexed.tsv"
)

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
    echo "$file" >> "$FAIL_LIST_FILE"
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

if (( VERBOSE == 1 )) && (( ${#TIMING_ROWS[@]} > 0 )); then
  echo "[mini-runner] FILE TIMINGS"
  rank=0
  while IFS=$'\t' read -r elapsed_ms file; do
    rank=$((rank + 1))
    printf '[mini-runner]   %02d. %6sms | %s\n' "$rank" "$elapsed_ms" "$file"
  done < <(printf '%s\n' "${TIMING_ROWS[@]}" | sort -rn -k1,1)
fi

echo "[mini-runner] TOTAL ${#TEST_FILES[@]} file(s) | failed=$FAIL_FILES | elapsed=${TOTAL_DT_MS}ms"

if (( FAIL_FILES > 0 )); then
  echo "[mini-runner] rerun failed only: TEST_FAILED_ONLY=1 ./scripts/test-mini.sh"
  echo "[mini-runner] rerun one file:    ./scripts/test-mini.sh tests/unit/test_query_unit.lua"
  echo "[mini-runner] failed list path:  $FAIL_LIST_FILE"
  exit 1
fi
