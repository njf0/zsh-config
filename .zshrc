# Portable Zsh configuration for macOS and Linux.

# Keep per-machine state out of this repository.
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
typeset -g ZSH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p -m 700 "$ZSH_CACHE_DIR"
[[ -d "$ZSH_STATE_DIR" ]] || mkdir -p -m 700 "$ZSH_STATE_DIR"

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
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushd_silent

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

# Prefer selected modern tools without replacing the entire macOS userland.
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  [[ -d "$HOMEBREW_PREFIX/opt/curl/bin" ]] && \
    path=("$HOMEBREW_PREFIX/opt/curl/bin" $path)
  [[ -d "$HOMEBREW_PREFIX/opt/make/libexec/gnubin" ]] && \
    path=("$HOMEBREW_PREFIX/opt/make/libexec/gnubin" $path)
fi
export PATH

# Prefer a straightforward terminal editor while respecting existing overrides.
if [[ -z "${EDITOR:-}" ]]; then
  if (( $+commands[nano] )); then
    EDITOR=nano
  else
    EDITOR=vi
  fi
fi
export EDITOR
export VISUAL="${VISUAL:-$EDITOR}"

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

# Open the current command in $VISUAL or $EDITOR, then return it to the prompt.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M emacs '^X^E' edit-command-line
bindkey -M viins '^X^E' edit-command-line

# Copy command-line text to the OS clipboard or read text back from it.
function _zsh_clipboard_write() {
  if (( $+commands[pbcopy] )); then
    command pbcopy
  elif (( $+commands[wl-copy] )); then
    command wl-copy
  elif (( $+commands[xclip] )); then
    command xclip -selection clipboard
  elif (( $+commands[xsel] )); then
    command xsel --clipboard --input
  else
    return 127
  fi
}

function _zsh_clipboard_read() {
  if (( $+commands[pbpaste] )); then
    command pbpaste
  elif (( $+commands[wl-paste] )); then
    command wl-paste --no-newline
  elif (( $+commands[xclip] )); then
    command xclip -selection clipboard -o
  elif (( $+commands[xsel] )); then
    command xsel --clipboard --output
  else
    return 127
  fi
}

function copy-command-line-to-clipboard() {
  if print -rn -- "$BUFFER" | _zsh_clipboard_write; then
    zle -M "Copied command line"
  else
    zle -M "Clipboard unavailable"
    return 1
  fi
}

function insert-quoted-clipboard() {
  local clipboard
  clipboard="$(_zsh_clipboard_read)" || {
    zle -M "Clipboard unavailable"
    return 1
  }

  if [[ -z "$clipboard" ]]; then
    zle -M "Clipboard is empty"
    return
  fi

  LBUFFER+="${(q)clipboard}"
}

zle -N copy-command-line-to-clipboard
zle -N insert-quoted-clipboard
bindkey -M emacs '^X^C' copy-command-line-to-clipboard
bindkey -M viins '^X^C' copy-command-line-to-clipboard
bindkey -M emacs '^X^V' insert-quoted-clipboard
bindkey -M viins '^X^V' insert-quoted-clipboard

# Search history using everything typed before the cursor as the prefix.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
for keymap in emacs viins; do
  bindkey -M "$keymap" '^[[A' up-line-or-beginning-search
  bindkey -M "$keymap" '^[[B' down-line-or-beginning-search
  bindkey -M "$keymap" '^[OA' up-line-or-beginning-search
  bindkey -M "$keymap" '^[OB' down-line-or-beginning-search
done
unset keymap

# Enable fzf's official Zsh bindings when the binary is available.
if (( $+commands[fzf] )); then
  if [[ -z "${FZF_DEFAULT_OPTS:-}" ]]; then
    FZF_DEFAULT_OPTS="--height=70% --layout=reverse --border --info=inline"
  fi
  if [[ -z "${FZF_CTRL_T_OPTS:-}" ]]; then
    FZF_CTRL_T_OPTS="
      --walker-skip .git,node_modules,.venv,target
      --preview 'if [[ -d {} ]]; then command ls -la -- {}; elif command file --mime-type -b -- {} | command grep -Eq \"^(text/|application/(json|xml|javascript))\"; then if command -v bat >/dev/null; then command bat --style=numbers --color=always --line-range=:200 -- {}; else command sed -n 1,200p -- {}; fi; else command file --brief -- {}; fi'
      --preview-window 'right,50%,border-left'
      --bind 'ctrl-/:toggle-preview'"
  fi
  if [[ -z "${FZF_ALT_C_OPTS:-}" ]]; then
    FZF_ALT_C_OPTS="
      --walker-skip .git,node_modules,.venv,target
      --preview 'command ls -la -- {}'
      --preview-window 'right,50%,border-left'
      --bind 'ctrl-/:toggle-preview'"
  fi
  export FZF_DEFAULT_OPTS FZF_CTRL_T_OPTS FZF_ALT_C_OPTS
  source <(fzf --zsh)
fi

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
  builtin cd -- "$root" || return
}

function take() {
  if (( $# != 1 )); then
    print -u2 "Usage: take directory"
    return 2
  fi

  mkdir -p -- "$1" && builtin cd -- "$1"
}

function up() {
  if (( $# > 1 )); then
    print -u2 "Usage: up [levels]"
    return 2
  fi

  local levels="${1:-1}"
  if [[ "$levels" != <-> ]] || (( levels < 1 )); then
    print -u2 "Usage: up [positive integer]"
    return 2
  fi

  local destination=".."
  local -i remaining=$levels
  while (( --remaining > 0 )); do
    destination+="/.."
  done

  builtin cd -- "$destination"
}

function git-pick() {
  if (( ! $+commands[fzf] )); then
    print -u2 "git-pick requires fzf"
    return 1
  fi
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print -u2 "git-pick must be run inside a Git working tree"
    return 1
  fi
  if (( $# > 1 )); then
    print -u2 "Usage: git-pick [branch|worktree]"
    return 2
  fi

  local mode="${1:-branch}"
  local selection
  case "$mode" in
    branch)
      selection="$(
        git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads |
          fzf --prompt='branch> ' \
            --header='Enter: switch local branch | Esc: cancel' \
            --preview 'git log --color=always --date=short --pretty=format:"%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %s %C(blue)(%an)%C(reset)" -n 20 -- {}' \
            --preview-window='right,60%,border-left'
      )" || return 0
      [[ -n "$selection" ]] && git switch -- "$selection"
      ;;
    worktree)
      selection="$(
        git worktree list --porcelain | command sed -n 's/^worktree //p' |
          fzf --prompt='worktree> ' \
            --header='Enter: change directory | Esc: cancel' \
            --preview 'git -C {} log --color=always --date=short --pretty=format:"%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %s %C(blue)(%an)%C(reset)" -n 20' \
            --preview-window='right,60%,border-left'
      )" || return 0
      [[ -n "$selection" ]] && builtin cd -- "$selection"
      ;;
    *)
      print -u2 "Usage: git-pick [branch|worktree]"
      return 2
      ;;
  esac
}

function _git_pick() {
  _values 'picker' branch worktree
}
compdef _git_pick git-pick

# Git information in the prompt.
zstyle ':vcs_info:git:*' enable git
zstyle ':vcs_info:git:*' formats '/%F{green}%c%u%b%f'
zstyle ':vcs_info:git:*' actionformats '/%F{green}%c%u%b%f %F{yellow}(%a)%f'
zstyle ':vcs_info:git:*' stagedstr '%F{yellow}'
zstyle ':vcs_info:git:*' unstagedstr '%F{red}'
zstyle ':vcs_info:git:*' check-for-changes true

function update_vcs_info() {
  vcs_info
}

# Show how long the previous command took.
zmodload zsh/datetime
typeset -g COMMAND_STARTED_AT=""
typeset -g COMMAND_ELAPSED=""
typeset -g COMMAND_SPEED=""
typeset -gi COMMAND_DURATION_SECONDS=0
typeset -g LONG_COMMAND_NOTIFY_AFTER="${LONG_COMMAND_NOTIFY_AFTER:-30}"

function start_command_timer() {
  COMMAND_STARTED_AT="$EPOCHREALTIME"
}

function update_command_timer() {
  if [[ -z "$COMMAND_STARTED_AT" ]]; then
    COMMAND_ELAPSED=""
    COMMAND_SPEED=""
    COMMAND_DURATION_SECONDS=0
    return
  fi

  local -F 6 duration=$(( EPOCHREALTIME - COMMAND_STARTED_AT ))
  local -i total_us=$(( duration * 1000000 ))
  local -i total_ms=$(( total_us / 1000 ))
  local -i total_seconds=$(( total_ms / 1000 ))
  COMMAND_DURATION_SECONDS=$total_seconds
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

function terminal_is_background() {
  [[ "$OSTYPE" == darwin* ]] || return 1
  (( $+commands[osascript] )) || return 1

  local terminal_bundle="${__CFBundleIdentifier:-}"
  if [[ -z "$terminal_bundle" ]]; then
    case "${TERM_PROGRAM:-}" in
      Apple_Terminal) terminal_bundle="com.apple.Terminal" ;;
      iTerm.app) terminal_bundle="com.googlecode.iterm2" ;;
      vscode) terminal_bundle="com.microsoft.VSCode" ;;
      WezTerm) terminal_bundle="com.github.wez.wezterm" ;;
      WarpTerminal) terminal_bundle="dev.warp.Warp-Stable" ;;
      ghostty) terminal_bundle="com.mitchellh.ghostty" ;;
      *) return 1 ;;
    esac
  fi

  local frontmost_bundle
  frontmost_bundle="$(command osascript -l JavaScript \
    -e 'ObjC.import("AppKit"); ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier)' \
    2>/dev/null)" || return 1
  [[ -n "$frontmost_bundle" && "$frontmost_bundle" != "$terminal_bundle" ]]
}

function _send_long_command_notification() {
  command osascript \
    -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title "Long command finished"' \
    -e 'end run' \
    "$1" >/dev/null 2>&1 &!
}

function notify_long_command() {
  local threshold="${LONG_COMMAND_NOTIFY_AFTER:-30}"
  [[ "$threshold" == <-> ]] || return 0
  (( threshold > 0 && COMMAND_DURATION_SECONDS >= threshold )) || return 0
  terminal_is_background || return 0
  _send_long_command_notification \
    "Finished after ${COMMAND_ELAPSED:-${COMMAND_DURATION_SECONDS}s}"
}

add-zsh-hook preexec start_command_timer
add-zsh-hook precmd update_command_timer
add-zsh-hook precmd notify_long_command
add-zsh-hook precmd update_vcs_info

# Switch prompt presentation without restarting the shell.
function prompt-style() {
  if (( $# == 0 )); then
    print "Current prompt style: ${PROMPT_STYLE:-standard}"
    print "Available styles: minimal, standard, maximal"
    return
  fi

  local style="$1"
  case "$style" in
    minimal)
      PROMPT='%F{magenta}%1~%f${vcs_info_msg_0_} %(?.%F{green}✓.%F{red}✗)%f '
      RPROMPT=''
      ;;
    standard)
      PROMPT='%F{yellow}${COMMAND_ELAPSED}%f${COMMAND_ELAPSED:+ }%F{cyan}%n%f@%F{blue}%m%f:%F{magenta}%1~%f${vcs_info_msg_0_} %(?.%F{green}✓.%F{red}✗)%f '
      RPROMPT=''
      ;;
    maximal)
      PROMPT='${COMMAND_SPEED:+${COMMAND_SPEED} }%F{yellow}${COMMAND_ELAPSED}%f${COMMAND_ELAPSED:+ }%F{cyan}%n%f@%F{blue}%m%f:%F{magenta}%~%f${vcs_info_msg_0_} %(?.%F{green}✓.%F{red}✗)%f '
      RPROMPT='%F{blue}📅 %D{%a %d %b}%f %F{green}🕒 %D{%H:%M}%f'
      ;;
    *)
      print -u2 "Usage: prompt-style minimal|standard|maximal"
      return 2
      ;;
  esac

  typeset -g PROMPT_STYLE="$style"
}

function _prompt_style() {
  _values 'prompt style' minimal standard maximal
}
compdef _prompt_style prompt-style

# Put private keys, work-specific paths, and other machine-local settings here.
typeset -g ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
typeset -g ZSH_LOCAL_CONFIG="${ZSH_LOCAL_CONFIG:-$ZSH_CONFIG_DIR/local.zsh}"
[[ -r "$ZSH_LOCAL_CONFIG" ]] && source "$ZSH_LOCAL_CONFIG"

prompt-style "${PROMPT_STYLE:-standard}"

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# zsh-syntax-highlighting should be sourced after all other shell configuration.
if [[ -n "$HOMEBREW_PREFIX" && \
      -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
