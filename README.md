# Zsh and development config

A small, portable configuration for macOS and Linux. It includes:

- A Zsh prompt with Git status and previous-command timing
- Selectable, typo-tolerant completions
- Optional autosuggestions and syntax highlighting
- Homebrew-managed Zsh as the login shell when explicitly requested
- A minimal Homebrew package set
- Personal Ruff defaults that yield to project configuration
- A private, per-machine override file outside the repository

## Install

macOS already includes Zsh. Install Homebrew first if it is not already
available, then clone this public repository over HTTPS:

```sh
git clone https://github.com/njf0/zsh-config.git ~/.config/zsh-config
~/.config/zsh-config/install.zsh --brew --set-shell
```

The installer backs up existing files before linking `.zshrc`, `.zprofile`, and
the Ruff fallback into their standard locations. It never edits `/etc/shells`
with elevated privileges: if Homebrew Zsh is not yet registered, it prints the
single command to run before retrying `--set-shell`. Fully quit and reopen the
terminal after changing the login shell.

Omit both options to install only the configuration links.

## Homebrew packages

The deliberately small `Brewfile` installs:

- Ruff and uv
- Zsh
- zsh-autosuggestions
- zsh-completions
- zsh-syntax-highlighting

Install or reconcile it independently with:

```sh
brew bundle --file ~/.config/zsh-config/Brewfile --no-upgrade
```

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

## Optional ideas

These are deliberately not installed or enabled yet:

- [ ] Add a cached weather segment to the right prompt, showing an emoji and
      temperature from wttr.in. Refresh it in the background, fail silently,
      never block prompt rendering, and keep the location in `local.zsh`.
- [ ] Add fzf shell integration for searchable history (`Ctrl-R`), file
      insertion (`Ctrl-T`), and directory navigation (`Alt-C`).
- [ ] Enrich the Git prompt with ahead/behind counts, stash count, conflicts,
      and conspicuous merge or rebase states without slowing large repositories.
- [ ] Send a macOS notification when a long-running command finishes while the
      terminal is not focused.
- [ ] Collapse completed commands to a small transient prompt while retaining
      the fully decorated current prompt.
- [ ] Add optional zoxide integration for learned directory jumping.

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
