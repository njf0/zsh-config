#!/bin/sh

set -eu

repo_url="${ZSH_CONFIG_REPO_URL:-https://github.com/njf0/zsh-config.git}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
repo_dir="${ZSH_CONFIG_REPO_DIR:-$config_home/zsh-config}"
assume_yes="${ZSH_CONFIG_ASSUME_YES:-0}"
skip_shell="${ZSH_CONFIG_SKIP_SHELL:-0}"

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

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  for candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [ "$(id -u)" -eq 0 ]; then
  fail "Run this bootstrap as your normal user, not as root."
fi

system_name=$(uname -s)
package_family=""
case "$system_name" in
  Darwin)
    platform="macOS"
    ;;
  Linux)
    if [ ! -r /etc/os-release ]; then
      fail "Linux was detected, but /etc/os-release is unavailable."
    fi
    # This file is supplied by the operating system.
    . /etc/os-release
    case "${ID:-} ${ID_LIKE:-}" in
      *ubuntu*|*debian*) package_family="debian" ;;
      *) fail "Only Ubuntu and Debian Linux distributions are supported." ;;
    esac
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
      platform="WSL 2 (${PRETTY_NAME:-Linux})"
    else
      platform="${PRETTY_NAME:-Ubuntu/Debian Linux}"
    fi
    ;;
  *)
    fail "Unsupported operating system: $system_name"
    ;;
esac

say "Zsh configuration machine bootstrap"
say "Platform: $platform"
say "Repository: $repo_url"
say "Destination: $repo_dir"
say ""
say "This will:"
if [ "$package_family" = debian ]; then
  say "  - install only missing Homebrew prerequisites with apt"
fi
say "  - install Homebrew when it is absent"
say "  - clone the repository when it is absent"
say "  - install the Brewfile without upgrading existing packages"
say "  - back up and link the shared configuration"
if [ "$skip_shell" = 1 ]; then
  say "  - leave the login shell unchanged"
else
  say "  - optionally register and select Homebrew Zsh as the login shell"
fi
say ""

if ! confirm "Continue?"; then
  say "Cancelled without making changes."
  exit 0
fi

if [ "$package_family" = debian ]; then
  missing_packages=""
  for package in build-essential procps curl file git ca-certificates; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
      grep -q 'ok installed'
    then
      missing_packages="$missing_packages $package"
    fi
  done

  if [ -n "$missing_packages" ]; then
    command -v sudo >/dev/null 2>&1 ||
      fail "sudo is required to install:$missing_packages"
    say "Installing missing OS prerequisites:$missing_packages"
    sudo apt-get update
    # Package names are fixed above and intentionally split here.
    sudo apt-get install -y $missing_packages
  else
    say "OS prerequisites are already installed."
  fi
fi

brew_bin=$(find_brew || true)
if [ -z "$brew_bin" ]; then
  command -v curl >/dev/null 2>&1 || fail "curl is required to install Homebrew."
  command -v bash >/dev/null 2>&1 || fail "bash is required to install Homebrew."
  say "Starting the official Homebrew installer."
  homebrew_installer="$(
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  )"
  /bin/bash -c "$homebrew_installer"
  brew_bin=$(find_brew || true)
  [ -n "$brew_bin" ] || fail "Homebrew installation finished, but brew was not found."
else
  say "Homebrew is already installed: $brew_bin"
fi

eval "$("$brew_bin" shellenv)"
brew_bin=$(command -v brew)

if ! command -v git >/dev/null 2>&1; then
  say "Git is not available; installing it with Homebrew."
  "$brew_bin" install git
fi

if [ -e "$repo_dir" ]; then
  git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "$repo_dir exists but is not a Git working tree."
  origin_url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
  expected_base=${repo_url%.git}
  origin_base=${origin_url%.git}
  if [ -z "$origin_url" ] || [ "$origin_base" != "$expected_base" ]; then
    fail "$repo_dir has an unexpected origin: ${origin_url:-<none>}"
  fi
  say "Using the existing checkout unchanged: $repo_dir"
else
  mkdir -p "$(dirname "$repo_dir")"
  git clone -- "$repo_url" "$repo_dir"
fi

installer="$repo_dir/install.sh"
if [ ! -f "$installer" ]; then
  fail "$installer is missing. Update the checkout explicitly, then rerun."
fi

/bin/sh "$installer" --brew

if [ "$skip_shell" != 1 ]; then
  brew_zsh="$("$brew_bin" --prefix)/bin/zsh"
  [ -x "$brew_zsh" ] || fail "Homebrew Zsh is missing at $brew_zsh"

  current_shell="${SHELL:-}"
  if command -v getent >/dev/null 2>&1; then
    current_shell=$(getent passwd "$(id -un)" | awk -F: '{print $7}')
  elif [ "$system_name" = Darwin ] && command -v dscl >/dev/null 2>&1; then
    current_shell=$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null |
      awk '{print $2}')
  fi

  if [ "$current_shell" = "$brew_zsh" ]; then
    say "Homebrew Zsh is already the login shell: $brew_zsh"
  elif confirm "Register $brew_zsh and make it your login shell?"; then
    if ! grep -Fxq "$brew_zsh" /etc/shells; then
      command -v sudo >/dev/null 2>&1 ||
        fail "sudo is required to register Homebrew Zsh in /etc/shells."
      printf '%s\n' "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$brew_zsh"
    say "Login shell changed to: $brew_zsh"
  else
    say "Login shell left unchanged."
  fi
fi

say ""
say "Setup complete. Fully close and reopen the terminal, then verify with:"
say '  echo "$SHELL"'
say '  zsh --version'
