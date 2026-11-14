# Portable Zsh configuration for macOS and Linux.

# Keep per-machine state out of this repository.
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
typeset -g ZSH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"
[[ -d "$ZSH_STATE_DIR" ]] || mkdir -p "$ZSH_STATE_DIR"

HISTFILE="$ZSH_STATE_DIR/history"
HISTSIZE=50000
SAVEHIST=50000

setopt append_history
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt interactive_comments
setopt prompt_subst

# Homebrew can live in different locations on Apple Silicon, Intel macOS, and Linux.
if (( $+commands[brew] )); then
  typeset -g HOMEBREW_PREFIX="$(brew --prefix)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  typeset -g HOMEBREW_PREFIX=/opt/homebrew
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
  typeset -g HOMEBREW_PREFIX=/usr/local
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  typeset -g HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
else
  typeset -g HOMEBREW_PREFIX=""
fi

# Homebrew-provided completions must be added before compinit runs.
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  [[ -d "$HOMEBREW_PREFIX/share/zsh-completions" ]] && \
    fpath=("$HOMEBREW_PREFIX/share/zsh-completions" $fpath)
  [[ -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]] && \
    fpath=("$HOMEBREW_PREFIX/share/zsh/site-functions" $fpath)
fi

zmodload zsh/complist
autoload -Uz compinit vcs_info add-zsh-hook zmv
compinit -d "$ZSH_CACHE_DIR/zcompdump"

# Selectable, typo-tolerant completion with useful descriptions.
zstyle ':completion:*' menu select=2
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' completer _complete _approximate
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/completion"
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' accept-exact '*(N)'

if [[ -n "$HOMEBREW_PREFIX" && \
      -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Small aliases and helpers.
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  alias brewup='brew update -v && brew upgrade'
  alias brewdown='brew cleanup -v && brew autoremove -v && brew doctor'
fi
alias md='mkdir -p'
alias pd='cd -'
if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi

function cdgr() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return
  cd "$root" || return
}

# Git information in the prompt.
zstyle ':vcs_info:git:*' enable git
zstyle ':vcs_info:git:*' formats '/%F{green}%b%f%u%c'
zstyle ':vcs_info:git:*' actionformats '/%F{green}%b%f %F{yellow}(%a)%f%u%c'
zstyle ':vcs_info:git:*' stagedstr '%F{yellow}●%f'
zstyle ':vcs_info:git:*' unstagedstr '%F{red}●%f'
zstyle ':vcs_info:git:*' check-for-changes true

function update_vcs_info() {
  vcs_info
}

# Show how long the previous command took.
zmodload zsh/datetime
typeset -g COMMAND_STARTED_AT=""
typeset -g COMMAND_ELAPSED=""
typeset -g COMMAND_SPEED=""

function start_command_timer() {
  COMMAND_STARTED_AT="$EPOCHREALTIME"
}

function update_command_timer() {
  if [[ -z "$COMMAND_STARTED_AT" ]]; then
    COMMAND_ELAPSED=""
    COMMAND_SPEED=""
    return
  fi

  local -F 6 duration=$(( EPOCHREALTIME - COMMAND_STARTED_AT ))
  local -i total_us=$(( duration * 1000000 ))
  local -i total_ms=$(( total_us / 1000 ))
  local -i total_seconds=$(( total_ms / 1000 ))
  local -i days=$(( total_seconds / 86400 ))
  local -i hours=$(( (total_seconds / 3600) % 24 ))
  local -i minutes=$(( (total_seconds / 60) % 60 ))
  local -i seconds=$(( total_seconds % 60 ))

  if (( days > 0 )); then
    COMMAND_ELAPSED="${days}d ${hours}h"
    COMMAND_SPEED="🐌"
  elif (( hours > 0 )); then
    COMMAND_ELAPSED="${hours}h ${minutes}m"
    COMMAND_SPEED="🦥"
  elif (( minutes >= 10 )); then
    COMMAND_ELAPSED="${minutes}m"
    COMMAND_SPEED="🐢"
  elif (( minutes > 0 )); then
    COMMAND_ELAPSED="${minutes}m ${seconds}s"
    COMMAND_SPEED="🚶"
  elif (( total_seconds >= 10 )); then
    COMMAND_ELAPSED="${seconds}s"
    COMMAND_SPEED="🚴"
  elif (( total_seconds > 0 )); then
    local -i tenths=$(( (total_ms % 1000) / 100 ))
    COMMAND_ELAPSED="${seconds}.${tenths}s"
    COMMAND_SPEED="🚄"
  elif (( total_ms >= 100 )); then
    COMMAND_ELAPSED="${total_ms}ms"
    COMMAND_SPEED="✈️"
  elif (( total_ms >= 10 )); then
    COMMAND_ELAPSED="${total_ms}ms"
    COMMAND_SPEED="🚀"
  elif (( total_ms > 0 )); then
    COMMAND_ELAPSED="${total_ms}ms"
    COMMAND_SPEED="🌠"
  else
    COMMAND_ELAPSED="${total_us}µs"
    COMMAND_SPEED="⚡"
  fi

  COMMAND_STARTED_AT=""
}

add-zsh-hook preexec start_command_timer
add-zsh-hook precmd update_command_timer
add-zsh-hook precmd update_vcs_info

PROMPT='${COMMAND_SPEED:+${COMMAND_SPEED} }%F{yellow}${COMMAND_ELAPSED}%f${COMMAND_ELAPSED:+ }%F{cyan}%n%f@%F{blue}%m%f:%F{magenta}%1~%f${vcs_info_msg_0_} %(?.%F{green}✓.%F{red}✗)%f '

# Put private keys, work-specific paths, and other machine-local settings here.
typeset -g ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
typeset -g ZSH_LOCAL_CONFIG="${ZSH_LOCAL_CONFIG:-$ZSH_CONFIG_DIR/local.zsh}"
[[ -r "$ZSH_LOCAL_CONFIG" ]] && source "$ZSH_LOCAL_CONFIG"

# zsh-syntax-highlighting should be sourced after all other shell configuration.
if [[ -n "$HOMEBREW_PREFIX" && \
      -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
