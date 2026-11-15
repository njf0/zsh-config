#!/bin/sh

# One setup entry point for fresh machines, existing checkouts, and migrations.
# Keep this script POSIX-compatible: a bare machine may not have Zsh yet.
set -eu

# Environment overrides make forks, test installs, and unattended setup possible
# without changing the common command shown in the README.
repo_url="${ZSH_CONFIG_REPO_URL:-https://github.com/njf0/zsh-config.git}"
assume_yes="${ZSH_CONFIG_ASSUME_YES:-0}"
skip_shell="${ZSH_CONFIG_SKIP_SHELL:-0}"
links_only=0

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: setup.sh [--links-only] [--skip-shell] [--yes]

  --links-only  Link configuration without installing Homebrew packages.
  --skip-shell  Do not offer to change the login shell.
  --yes         Accept confirmation prompts (intended for automation).
EOF
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

for argument in "$@"; do
  case "$argument" in
    --links-only) links_only=1 ;;
    --skip-shell) skip_shell=1 ;;
    --yes) assume_yes=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$(id -u)" -eq 0 ]; then
  fail "Run setup as your normal user, not as root."
fi

# A directly executed copy lives beside the repository files. A copy downloaded
# into `sh -c` has /bin/sh as $0, so it proceeds through the clone path instead.
local_repo=""
script_dir=$(CDPATH= cd -P "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "$script_dir" ] && \
  [ -f "$script_dir/.zshrc" ] && \
  [ -f "$script_dir/Brewfile" ] && \
  [ -f "$script_dir/local.zsh.example" ]
then
  local_repo="$script_dir"
fi

# Detect the supported host before making any changes. Ubuntu and Debian are
# supported both under WSL 2 and as ordinary Linux installations.
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
    # /etc/os-release is supplied by the operating system.
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

# ZDOTDIR changes where Zsh looks before ~/.zshrc can repair anything. Treat an
# inherited value, or a ~/.zshenv which manages it, as a migration. The old
# repository itself is deliberately never moved or deleted.
legacy_loader=""
if [ -r "$HOME/.zshenv" ] && \
  grep -Eq 'ZDOTDIR|XDG_CONFIG_HOME' "$HOME/.zshenv"
then
  legacy_loader="$HOME/.zshenv"
fi

migrate_legacy=0
if [ -n "${ZDOTDIR:-}" ] || [ -n "$legacy_loader" ]; then
  migrate_legacy=1
  config_home="$HOME/.config"
else
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
fi

if [ -n "$local_repo" ]; then
  repo_dir="$local_repo"
  install_source="existing checkout"
else
  repo_dir="${ZSH_CONFIG_REPO_DIR:-$config_home/zsh-config}"
  install_source="public repository"
fi

say "Zsh configuration setup"
say "Platform: $platform"
say "Source: $install_source"
say "Repository: $repo_url"
say "Destination: $repo_dir"
say ""
say "This will:"
if [ "$migrate_legacy" = 1 ]; then
  if [ -n "${ZDOTDIR:-}" ]; then
    say "  - replace the inherited ZDOTDIR setup: $ZDOTDIR"
  fi
  if [ -n "$legacy_loader" ]; then
    say "  - preserve $legacy_loader under a timestamped backup name"
  fi
  say "  - use $HOME/.config without deleting the old dotfiles repository"
fi
if [ -z "$local_repo" ]; then
  say "  - clone the repository when it is absent"
fi
if [ "$links_only" = 1 ]; then
  say "  - back up and link configuration files only"
else
  if [ "$package_family" = debian ]; then
    say "  - install only missing Homebrew prerequisites with apt"
  fi
  say "  - install Homebrew when it is absent"
  say "  - install the Brewfile without upgrading existing packages"
  say "  - back up and link the shared configuration"
  if [ "$skip_shell" = 1 ]; then
    say "  - leave the login shell unchanged"
  else
    say "  - optionally select Homebrew Zsh as the login shell"
  fi
fi
say ""

if ! confirm "Continue?"; then
  say "Cancelled without making changes."
  exit 0
fi

# Migration is intentionally conservative: only the Zsh loader is moved. Other
# startup files are reported for review because editing arbitrary shell code is
# riskier than leaving a clear, actionable note.
backup_stamp=$(date +%Y%m%d-%H%M%S)

unique_backup_name() {
  backup_base="$1.backup.$backup_stamp"
  backup_name="$backup_base"
  backup_counter=0
  while [ -e "$backup_name" ] || [ -L "$backup_name" ]; do
    backup_counter=$((backup_counter + 1))
    backup_name="$backup_base.$backup_counter"
  done
  printf '%s\n' "$backup_name"
}

if [ "$migrate_legacy" = 1 ]; then
  if [ -e "$HOME/.zshenv" ] || [ -L "$HOME/.zshenv" ]; then
    backup=$(unique_backup_name "$HOME/.zshenv")
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
fi

# Homebrew is installed before cloning so Git is available even on a genuinely
# minimal machine. links-only mode never installs system or Homebrew packages.
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

brew_bin=""
if [ "$links_only" != 1 ]; then
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
    [ -n "$brew_bin" ] ||
      fail "Homebrew installation finished, but brew was not found."
  else
    say "Homebrew is already installed: $brew_bin"
  fi

  eval "$("$brew_bin" shellenv)"
  brew_bin=$(command -v brew)

  if ! command -v git >/dev/null 2>&1; then
    say "Git is not available; installing it with Homebrew."
    "$brew_bin" install git
  fi
fi

# A downloaded copy clones the repository. A local copy uses its own checkout.
# Existing destinations are validated but never pulled, reset, or overwritten.
if [ -z "$local_repo" ]; then
  command -v git >/dev/null 2>&1 ||
    fail "Git is required to clone the configuration repository."

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
fi

for required_file in \
  "$repo_dir/.zshrc" \
  "$repo_dir/.zprofile" \
  "$repo_dir/Brewfile" \
  "$repo_dir/local.zsh.example" \
  "$repo_dir/ruff/ruff.toml"
do
  [ -f "$required_file" ] || fail "Required file is missing: $required_file"
done

# Link each shared file using an absolute source. Conflicting files and symlinks
# receive unique timestamped backups, making migration and reruns recoverable.
link_config() {
  source_file="$1"
  target_file="$2"

  mkdir -p "$(dirname "$target_file")"

  if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
    say "Already installed: $target_file -> $source_file"
    return
  fi

  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    backup=$(unique_backup_name "$target_file")
    mv "$target_file" "$backup"
    say "Backed up: $target_file -> $backup"
  fi

  ln -s "$source_file" "$target_file"
  say "Installed: $target_file -> $source_file"
}

link_config "$repo_dir/.zshrc" "$HOME/.zshrc"
link_config "$repo_dir/.zprofile" "$HOME/.zprofile"
link_config "$repo_dir/ruff/ruff.toml" "$config_home/ruff/ruff.toml"

local_dir="$config_home/zsh"
mkdir -p "$local_dir"
if [ ! -e "$local_dir/local.zsh" ]; then
  cp "$repo_dir/local.zsh.example" "$local_dir/local.zsh"
  chmod 600 "$local_dir/local.zsh"
  say "Created private local config: $local_dir/local.zsh"
fi

if [ "$links_only" != 1 ]; then
  "$brew_bin" bundle --file "$repo_dir/Brewfile" --no-upgrade
fi

# Changing the login shell remains a separate prompt. Registering Homebrew Zsh
# in /etc/shells requires sudo, while chsh itself runs as the normal user.
if [ "$links_only" != 1 ] && [ "$skip_shell" != 1 ]; then
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
