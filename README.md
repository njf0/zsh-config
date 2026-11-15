# Zsh and development config

A small, portable configuration for macOS and Linux. It includes:

- Three runtime-selectable prompts with Git status and command timing
- Selectable, typo-tolerant completions
- fzf-powered history, file, directory, and completion search
- Optional autosuggestions and syntax highlighting
- Homebrew-managed Zsh as the login shell when explicitly requested
- A minimal Homebrew package set
- Personal Ruff defaults that yield to project configuration
- A private, per-machine override file outside the repository

## Install

### Bare-machine setup

From a macOS terminal or an Ubuntu/Debian WSL shell, paste:

```sh
(command -v curl >/dev/null 2>&1 || {
  sudo apt-get update && sudo apt-get install -y curl
}) && setup="$(curl -fsSL https://raw.githubusercontent.com/njf0/zsh-config/main/bootstrap-machine.sh)" && /bin/sh -c "$setup"
```

The complete bootstrap is downloaded before it is executed. It shows its plan
and asks before making changes. On WSL it uses `apt` only for missing Homebrew
prerequisites, then Homebrew and the repository's Brewfile manage the terminal
tools. It installs Homebrew when necessary, clones this public repository, and
offers to register Homebrew Zsh as the login shell.

The bootstrap is safe to rerun after interruption. An existing checkout is
validated and used unchanged: it is never pulled, reset, or overwritten. For a
reproducible bootstrap version, replace `main` in the URL with a release tag or
commit SHA.

### Replacing an older dotfiles setup

If the current shell already exports `ZDOTDIR` or points `XDG_CONFIG_HOME` at an
older dotfiles repository, use the migration entry point instead:

```sh
migration="$(curl -fsSL https://raw.githubusercontent.com/njf0/zsh-config/main/migrate-old-dotfiles.sh)" && /bin/sh -c "$migration"
```

It shows its plan and asks before making changes. The migration preserves an
existing `~/.zshenv` under a timestamped backup name, clears the inherited
variables for the new installation, and then runs the normal bootstrap using
`~/.config`. The regular installer separately backs up `~/.zshrc` and
`~/.zprofile`. The old dotfiles repository is not changed or deleted.

If `.profile`, `.bash_profile`, or `.bashrc` also mentions `ZDOTDIR` or
`XDG_CONFIG_HOME`, the migration reports the file for later review rather than
editing unrelated shell startup code automatically. Fully close WSL and reopen
it after the migration.

### Manual setup

`install.sh` is the portable post-clone entry point for macOS and Linux. It
locates Homebrew, uses an existing Zsh when available, or installs Homebrew Zsh
before delegating to the main installer.

#### macOS

Install Homebrew first if it is not already available, then clone this public
repository over HTTPS:

```sh
git clone https://github.com/njf0/zsh-config.git ~/.config/zsh-config
~/.config/zsh-config/install.sh --brew --set-shell
```

#### WSL 2

On a new Ubuntu or Debian WSL 2 distribution, install Homebrew's Linux
prerequisites and Homebrew itself:

```sh
sudo apt update
sudo apt install -y build-essential procps curl file git
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

Then clone and install without needing Zsh in advance:

```sh
git clone https://github.com/njf0/zsh-config.git ~/.config/zsh-config
~/.config/zsh-config/install.sh --brew --set-shell
```

The post-clone installer backs up existing files before linking `.zshrc`,
`.zprofile`, and the Ruff fallback into their standard locations. It never
edits `/etc/shells` with elevated privileges: if Homebrew Zsh is not yet
registered, it prints the single command to run before retrying `--set-shell`.
The bare-machine bootstrap can perform that registration only after explicitly
asking. Fully quit and reopen the terminal after changing the login shell.

Omit both options to install only the configuration links.

## Homebrew packages

The deliberately small `Brewfile` installs:

- Modern Unix tools: coreutils, curl, GNU Make, and wget
- Everyday CLI tools: bat, fd, fzf, Git, jq, and ripgrep
- Ruff and uv
- zoxide
- Zsh
- zsh-autosuggestions
- zsh-completions
- zsh-syntax-highlighting

Install or reconcile it independently with:

```sh
brew bundle --file ~/.config/zsh-config/Brewfile --no-upgrade
```

## Homebrew-managed Unix tools

Homebrew's current `curl` and GNU Make intentionally take precedence over the
versions supplied by macOS. Their stable `opt` paths work across Intel macOS,
Apple Silicon, and Linuxbrew. The platform versions remain available by their
absolute paths, such as `/usr/bin/curl` and `/usr/bin/make` on macOS.

On macOS, GNU coreutils deliberately retain their `g` prefixes (`gdate`,
`greadlink`, `gtimeout`, and so on). The configuration does not add coreutils'
`gnubin` directory to `PATH`, avoiding an implicit global switch from BSD to GNU
semantics. Linux and WSL already provide a GNU userland.

The Brewfile also provides `jq`, `ripgrep`, `fd`, and `bat`. The fzf file picker
uses `bat` for text previews when it is available and retains its dependency-free
fallback otherwise.

## Homebrew Zsh as the login shell

The `--set-shell` option validates that Homebrew Zsh exists and is listed in
`/etc/shells` before calling `chsh`. The path is determined from `brew --prefix`,
so the same installer works on Intel macOS, Apple Silicon, and Linuxbrew.

Verify the result after reopening the terminal:

```sh
echo "$SHELL"
zsh --version
```

The system Zsh remains available as a recovery shell. To switch back on macOS:

```sh
chsh -s /bin/zsh
```

## Prompt styles

Change the current terminal's prompt immediately without restarting Zsh:

```sh
prompt-style minimal
prompt-style standard
prompt-style maximal
```

Running `prompt-style` without an argument shows the current and available
styles. Each open terminal keeps its own selection:

- `minimal` shows the current directory, Git state, and success or failure.
- `standard` is the default prompt with command duration, user and host,
  current directory, Git state, and success or failure.
- `maximal` uses the full abbreviated path and adds the date and time as a
  right-aligned prompt. A future weather segment can join it there.

Choose a default for future shells in `~/.config/zsh/local.zsh`:

```zsh
PROMPT_STYLE=maximal
```

## Edit the current command

Press `Ctrl-X Ctrl-E` to open the command currently at the prompt in your usual
editor. Save and close the editor to return the edited text to the prompt; it is
not run until you press Return.

The shared configuration defaults `$EDITOR` and `$VISUAL` to `nano` when it is
available, falling back to `vi`. Existing environment values are preserved, and
either can be overridden in `~/.config/zsh/local.zsh`. In Nano, press `Ctrl-O`
and Return to save, then `Ctrl-X` to return to the command line.

For VS Code instead, add this to `~/.config/zsh/local.zsh` so the shell waits
for the editor window to close:

```zsh
export EDITOR='code --wait'
export VISUAL="$EDITOR"
```

## Prefix-aware history

Type the beginning of a command and press Up or Down to move only through
matching history entries. For example, typing `git` and repeatedly pressing Up
cycles through previous commands beginning with `git`. On an empty command line,
the arrows retain their normal history behaviour.

## Directory stack

Ordinary `cd` commands automatically retain the directories you leave in a
quiet, duplicate-free stack local to the current shell. Inspect it with
`dirs -v`, then use `popd` to return to the previous entry. `cd -` continues to
toggle between the current and immediately previous directory.

```sh
cd ~/code/project-one
cd ~/code/project-two
dirs -v
popd
```

## Navigation helpers

- `take <directory>` creates a directory, including missing parents, and enters
  it.
- `up [levels]` moves up one parent by default, or several with a positive
  number such as `up 3`.
- `cdgr` moves from anywhere inside a Git working tree to its root.

```sh
take ~/code/new-project
up 2
cdgr
```

## Clipboard widgets

- Press `Ctrl-X Ctrl-C` to copy the entire command currently at the prompt.
- Press `Ctrl-X Ctrl-V` to insert clipboard text at the cursor as one
  shell-quoted argument. For example, type `cd ` and use the shortcut to insert
  a copied path without spaces or shell characters being misinterpreted.

Both shortcuts leave the command at the prompt for review rather than running
it. macOS uses its built-in `pbcopy` and `pbpaste`; Linux uses `wl-copy`,
`xclip`, or `xsel` when one is already installed.

## Fuzzy finding with fzf

When `fzf` is installed, its official Zsh integration provides:

- `Ctrl-R` to search command history and insert a selection at the prompt.
- `Ctrl-T` to find one or more files or directories and insert their safely
  quoted paths at the prompt.
- `Alt-C` to find and immediately enter a directory.
- `**` followed by Tab for fuzzy path completion.

File and directory pickers include a preview pane. Press `Ctrl-/` inside fzf to
hide or restore it, and Escape to cancel. Common large metadata directories such
as `.git`, `node_modules`, `.venv`, and `target` are skipped by these pickers.

## Learned directory jumps with zoxide

`zoxide` learns from ordinary directory changes across shell sessions without
replacing `cd`:

- `z <keywords>` jumps to the highest-ranked matching directory.
- `zi <keywords>` opens an interactive fzf picker over matching directories.

For example, after visiting `~/code/zsh-config` a few times, `z zsh` can jump
there from anywhere. More specific keywords narrow ambiguous matches, such as
`z code zsh`. Its database is machine-local and is not stored in this repository.

## Git branch and worktree picker

Run `git-pick` or `git-pick branch` inside a Git working tree to fuzzy-search
local branches, preview their latest commits, and switch to the selection. Run
`git-pick worktree` to search the repository's worktrees, preview their latest
commits, and change directory to the selection. Escape cancels without changing
anything.

## Long-command notifications

On macOS, commands lasting at least 30 seconds send a notification when the
terminal application is not frontmost. The notification includes only the
elapsed time, never the command text, so arguments and tokens cannot appear on
the lock screen.

Change the threshold, or disable notifications, in
`~/.config/zsh/local.zsh`:

```zsh
LONG_COMMAND_NOTIFY_AFTER=60  # seconds
# LONG_COMMAND_NOTIFY_AFTER=0 # disabled
```

If the terminal application or frontmost application cannot be identified, the
configuration conservatively sends no notification.

## Enhancement roadmap

Checked items are implemented by this configuration. Unchecked items remain
ideas and are not installed or enabled yet.

### Native Zsh improvements

- [x] Bind `Ctrl-X Ctrl-E` to edit the current command in `$EDITOR`, then return
      the edited command to the terminal ready to run.
- [x] Make Up and Down prefix-aware: after typing `git`, cycle only through
      history entries beginning with `git`.
- [x] Enable a quiet, duplicate-free directory stack using `auto_pushd`,
      `pushd_ignore_dups`, and `pushd_silent`.
- [x] Add small navigation helpers such as `take`, `up`, and a project-root
      shortcut without overriding standard commands.
- [x] Add clipboard-aware widgets for copying the current command or inserting
      safely shell-quoted paths.

### Tool-backed enhancements

- [x] Add fzf shell integration for searchable history (`Ctrl-R`), file
      insertion (`Ctrl-T`), and directory navigation (`Alt-C`), with previews
      where useful.
- [x] Add optional zoxide integration for learned directory jumping.
- [ ] Consider direnv for explicitly approved, project-specific environments
      that unload automatically when leaving a directory.
- [x] Build an fzf Git branch or worktree picker with a recent-commit preview.

### Prompt and feedback

- [ ] Add a cached weather segment to the right prompt, showing an emoji and
      temperature from wttr.in. Refresh it in the background, fail silently,
      never block prompt rendering, and keep the location in `local.zsh`.
- [x] Send a macOS notification when a long-running command finishes while the
      terminal is not focused.
- [ ] Enrich the Git prompt with ahead/behind counts, stash count, conflicts,
      and conspicuous merge or rebase states without slowing large repositories.
- [ ] Collapse completed commands to a small transient prompt while retaining
      the fully decorated current prompt.

### Portability

- [ ] Add optional WSL 2 clipboard fallbacks using `clip.exe` and PowerShell's
      `Get-Clipboard`, plus Windows notification delivery for long commands.
      The current clipboard widgets still work when Wayland or X11 clipboard
      tools are installed, and macOS-only notifications fail silently on WSL.

Future additions should remain optional, portable, quick to start, and quiet
when their dependencies or network services are unavailable. Machine-specific
locations, account names, and other private values belong in `local.zsh`.

## Ruff

The installer links the fallback configuration to:

```text
~/.config/ruff/ruff.toml
```

Ruff uses it when a project has no Ruff configuration. A project's own
`pyproject.toml`, `ruff.toml`, or `.ruff.toml` remains authoritative.

## Private or machine-specific configuration

Put private values, work-specific paths, and aliases in:

```text
~/.config/zsh/local.zsh
```

This file is outside the repository. Do not put API keys or other credentials in
the public checkout, even if their filenames appear in `.gitignore`.
