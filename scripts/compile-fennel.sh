#!/usr/bin/env sh
set -eu

if ! command -v fennel >/dev/null 2>&1; then
  echo "fennel compiler not found" >&2
  exit 1
fi

mkdir -p lua/metabuffer
fennel --compile fnl/metabuffer/init.fnl > lua/metabuffer/from_fennel.lua

echo "compiled fnl/metabuffer/init.fnl -> lua/metabuffer/from_fennel.lua"
