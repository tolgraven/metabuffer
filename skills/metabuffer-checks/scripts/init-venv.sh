#!/usr/bin/env bash

# Resolve this script path in both bash and zsh when sourced.
if [[ -n "${BASH_SOURCE:-}" ]]; then
  this_script="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  this_script="${(%):-%N}"
else
  this_script="$0"
fi

is_sourced=0
if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
  if [[ "$ZSH_EVAL_CONTEXT" == *:file ]]; then
    is_sourced=1
  fi
elif [[ "$this_script" != "$0" ]]; then
  is_sourced=1
fi

_meta_fail() {
  echo "$1" >&2
  if [[ "$is_sourced" -eq 1 ]]; then
    return 1
  fi
  exit 1
}

_meta_main() {
  local script_dir skill_dir venv_dir python_bin pyenv_python desired_py_ver existing_py_ver

  script_dir="$(cd "$(dirname "$this_script")" && pwd)"
  skill_dir="$(cd "$script_dir/.." && pwd)"
  venv_dir="$skill_dir/.venv"
  python_bin="${PYTHON_BIN:-python3}"

  # Prefer pyenv-selected Python when available so this stays aligned with the
  # user's configured runtime.
  if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    pyenv_python="$(pyenv which python3 2>/dev/null || true)"
    if [[ -n "${pyenv_python:-}" ]]; then
      python_bin="$pyenv_python"
    fi
  fi

  if ! command -v "$python_bin" >/dev/null 2>&1; then
    _meta_fail "[metabuffer-checks] missing python executable: $python_bin"
    return 1
  fi

  desired_py_ver="$("$python_bin" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"

  if [[ -x "$venv_dir/bin/python" ]]; then
    existing_py_ver="$("$venv_dir/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    if [[ "$existing_py_ver" != "$desired_py_ver" ]]; then
      echo "[metabuffer-checks] recreating venv: python $existing_py_ver -> $desired_py_ver"
      rm -rf "$venv_dir"
    fi
  fi

  if [[ ! -d "$venv_dir" ]]; then
    echo "[metabuffer-checks] creating venv at $venv_dir (python $desired_py_ver)"
    "$python_bin" -m venv "$venv_dir" || {
      _meta_fail "[metabuffer-checks] failed to create venv at $venv_dir"
      return 1
    }
  else
    echo "[metabuffer-checks] using existing venv at $venv_dir"
  fi

  # shellcheck disable=SC1091
  source "$venv_dir/bin/activate" || {
    _meta_fail "[metabuffer-checks] failed to activate venv at $venv_dir"
    return 1
  }

  if ! python -c "import yaml" >/dev/null 2>&1; then
    echo "[metabuffer-checks] installing PyYAML into venv"
    if ! python -m pip install --upgrade PyYAML; then
      _meta_fail "[metabuffer-checks] failed to install PyYAML (likely no network access). retry when online or configure pip to use an internal package index."
      return 1
    fi
  else
    echo "[metabuffer-checks] PyYAML already installed in venv"
  fi

  echo "[metabuffer-checks] venv ready: $venv_dir"
  echo "[metabuffer-checks] python: $(command -v python)"
  python -c "import yaml; print('[metabuffer-checks] PyYAML:', yaml.__version__)"

  if [[ "$is_sourced" -eq 0 ]]; then
    echo "[metabuffer-checks] note: run 'source $script_dir/init-venv.sh' to keep the venv active in your current shell"
  fi
}

if [[ "$is_sourced" -eq 1 ]]; then
  _meta_main "$@" || return 1
else
  set -euo pipefail
  _meta_main "$@"
fi
