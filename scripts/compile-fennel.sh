#!/usr/bin/env sh
set -eu

if ! command -v fennel >/dev/null 2>&1; then
  echo "fennel compiler not found" >&2
  exit 1
fi

# Clean compiled outputs so stale modules are removed.
rm -rf lua
mkdir -p lua plugin

# Compile fnl/* -> lua/* and fnl/plugin/* -> plugin/*
find fnl -type f -name '*.fnl' | while IFS= read -r src; do
  case "$src" in
    fnl/plugin/*)
      out="${src#fnl/}"
      out="${out%.fnl}.lua"
      ;;
    *)
      out="lua/${src#fnl/}"
      out="${out%.fnl}.lua"
      ;;
  esac

  mkdir -p "$(dirname "$out")"
  fennel --compile "$src" > "$out"
  echo "compiled $src -> $out"
done
