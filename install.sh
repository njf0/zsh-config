#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
needs_brew=false

for argument in "$@"; do
  case "$argument" in
    --brew|--set-shell) needs_brew=true ;;
    *)
      printf '%s\n' "Usage: $0 [--brew] [--set-shell]" >&2
      exit 2
      ;;
  esac
done

brew_bin=""
if command -v brew >/dev/null 2>&1; then
  brew_bin=$(command -v brew)
else
  for candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew
  do
    if [ -x "$candidate" ]; then
      brew_bin="$candidate"
      break
    fi
  done
fi

if [ -z "$brew_bin" ] && [ "$needs_brew" = true ]; then
  printf '%s\n' \
    "Homebrew is required for --brew and --set-shell." \
    "Install it from https://brew.sh, then rerun this command." >&2
  exit 1
fi

if [ -n "$brew_bin" ]; then
  eval "$("$brew_bin" shellenv)"
  brew_bin=$(command -v brew)
fi

zsh_bin=""
if [ -n "$brew_bin" ]; then
  brew_zsh="$("$brew_bin" --prefix)/bin/zsh"
  if [ -x "$brew_zsh" ]; then
    zsh_bin="$brew_zsh"
  fi
fi

if [ -z "$zsh_bin" ] && command -v zsh >/dev/null 2>&1; then
  zsh_bin=$(command -v zsh)
fi

if [ -z "$zsh_bin" ]; then
  if [ -z "$brew_bin" ]; then
    printf '%s\n' \
      "Zsh is not installed and Homebrew is unavailable." \
      "Install Homebrew from https://brew.sh, then rerun this command." >&2
    exit 1
  fi

  printf '%s\n' "Zsh is not installed; bootstrapping it with Homebrew."
  "$brew_bin" install zsh
  brew_zsh="$("$brew_bin" --prefix)/bin/zsh"
  if [ ! -x "$brew_zsh" ]; then
    printf '%s\n' "Homebrew did not install Zsh at $brew_zsh" >&2
    exit 1
  fi
  zsh_bin="$brew_zsh"
fi

exec "$zsh_bin" "$repo_dir/install.zsh" "$@"
