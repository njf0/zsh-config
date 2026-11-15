#!/bin/sh

set -eu

bootstrap_url="${ZSH_CONFIG_BOOTSTRAP_URL:-https://raw.githubusercontent.com/njf0/zsh-config/main/bootstrap-machine.sh}"
assume_yes="${ZSH_CONFIG_ASSUME_YES:-0}"
backup_stamp="$(date +%Y%m%d-%H%M%S)"

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

confirm() {
  if [ "$assume_yes" = 1 ]; then
    return 0
  fi

  printf '%s [y/N] ' "$1"
  answer=""
  IFS= read -r answer || return 1
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$(id -u)" -eq 0 ]; then
  fail "Run this migration as your normal user, not as root."
fi

say "Zsh configuration migration"
say ""
say "This will:"
say "  - preserve any ~/.zshenv under a timestamped backup name"
say "  - ignore inherited ZDOTDIR and XDG_CONFIG_HOME values"
say "  - run the normal machine bootstrap using ~/.config"
say "  - leave the old dotfiles repository untouched"
say ""

if [ -n "${ZDOTDIR:-}" ]; then
  say "Detected ZDOTDIR=$ZDOTDIR"
fi
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  say "Detected XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
fi

if ! confirm "Continue with the migration?"; then
  say "Cancelled without making changes."
  exit 0
fi

if [ -e "$HOME/.zshenv" ] || [ -L "$HOME/.zshenv" ]; then
  backup="$HOME/.zshenv.backup.$backup_stamp"
  counter=0
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    counter=$((counter + 1))
    backup="$HOME/.zshenv.backup.$backup_stamp.$counter"
  done
  mv "$HOME/.zshenv" "$backup"
  say "Backed up: $HOME/.zshenv -> $backup"
fi

for startup_file in \
  "$HOME/.profile" \
  "$HOME/.bash_profile" \
  "$HOME/.bash_login" \
  "$HOME/.bashrc"
do
  if [ -r "$startup_file" ] && \
    grep -Eq 'ZDOTDIR|XDG_CONFIG_HOME' "$startup_file"
  then
    say "Review legacy variable references later: $startup_file"
  fi
done

unset ZDOTDIR XDG_CONFIG_HOME

command -v curl >/dev/null 2>&1 || fail "curl is required to download the bootstrap."
bootstrap="$(curl -fsSL "$bootstrap_url")" || fail "Could not download the machine bootstrap."

/bin/sh -c "$bootstrap"

say ""
say "Migration complete. Fully close and reopen the terminal."
