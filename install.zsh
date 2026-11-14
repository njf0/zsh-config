#!/bin/zsh

set -eu

repo_dir="${0:A:h}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
local_dir="$config_home/zsh"
install_brew=false
backup_stamp="$(date +%Y%m%d-%H%M%S)"

if (( $# > 1 )) || [[ "${1:-}" != "" && "${1:-}" != "--brew" ]]; then
  print -u2 "Usage: $0 [--brew]"
  exit 2
fi
[[ "${1:-}" == "--brew" ]] && install_brew=true

function link_config() {
  local source="$1"
  local target="$2"

  mkdir -p "${target:h}"

  if [[ -L "$target" && "${target:A}" == "${source:A}" ]]; then
    print "Already installed: $target -> $source"
    return
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    local backup="$target.backup.$backup_stamp"
    mv "$target" "$backup"
    print "Backed up: $target -> $backup"
  fi

  ln -s "$source" "$target"
  print "Installed: $target -> $source"
}

link_config "$repo_dir/.zshrc" "$HOME/.zshrc"
link_config "$repo_dir/.zprofile" "$HOME/.zprofile"
link_config "$repo_dir/ruff/ruff.toml" "$config_home/ruff/ruff.toml"

mkdir -p "$local_dir"
if [[ ! -e "$local_dir/local.zsh" ]]; then
  cp "$repo_dir/local.zsh.example" "$local_dir/local.zsh"
  chmod 600 "$local_dir/local.zsh"
  print "Created private local config: $local_dir/local.zsh"
fi

if $install_brew; then
  if ! command -v brew >/dev/null 2>&1; then
    print -u2 "Homebrew is not installed; install it first, then rerun with --brew."
    exit 1
  fi
  brew bundle --file "$repo_dir/Brewfile" --no-upgrade
fi

if [[ -n "${ZDOTDIR:-}" || -n "${XDG_CONFIG_HOME:-}" ]]; then
  print "This shell has ZDOTDIR or XDG_CONFIG_HOME set. To clear inherited old values:"
  print "  unset ZDOTDIR XDG_CONFIG_HOME; exec zsh -l"
else
  print "Restart the shell with: exec zsh -l"
fi
