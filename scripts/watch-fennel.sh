#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

INTERVAL=0.4
DO_COMPILE=0
RUN_ONCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --compile) DO_COMPILE=1 ;;
    --once) RUN_ONCE=1 ;;
    --interval=*) INTERVAL=${1#*=} ;;
    *)
      echo "unknown arg: $1" >&2
      echo "usage: $0 [--once] [--compile] [--interval=0.4]" >&2
      exit 2
      ;;
  esac
  shift
done

file_signature() {
  # Stable content signature over Fennel sources + nfnl config.
  # shellcheck disable=SC2016
  find fnl -type f \( -name '*.fnl' -o -name '*.fnlm' \) -print \
    | LC_ALL=C sort \
    | while IFS= read -r f; do
        [ -f "$f" ] && shasum "$f"
      done
  [ -f .nfnl.fnl ] && shasum .nfnl.fnl || true
}

run_checks() {
  printf '\n[%s] linting fnl...\n' "$(date '+%H:%M:%S')"
  if [ "$DO_COMPILE" -eq 1 ]; then
    echo "[watch-fennel] compiling..."
    if ./scripts/compile-fennel.sh; then
      echo "[watch-fennel] compile: ok"
    else
      echo "[watch-fennel] compile: failed"
      return 1
    fi
  fi
}

last_sig=""

while :; do
  sig=$({ file_signature; } | shasum | awk '{print $1}')
  if [ "$sig" != "$last_sig" ]; then
    last_sig=$sig
    run_checks || true
    [ "$RUN_ONCE" -eq 1 ] && exit 0
  fi
  sleep "$INTERVAL"
done

