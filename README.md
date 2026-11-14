# Zsh and development config

A small, portable configuration for macOS and Linux. It includes:

- A Zsh prompt with Git status and previous-command timing
- Selectable, typo-tolerant completions
- Optional autosuggestions and syntax highlighting
- A minimal Homebrew package set
- Personal Ruff defaults that yield to project configuration
- A private, per-machine override file outside the repository

## Install

macOS already includes Zsh. Install Homebrew first if it is not already
available, then clone this public repository over HTTPS:

```sh
git clone https://github.com/njf0/zsh-config.git ~/.config/zsh-config
~/.config/zsh-config/install.zsh --brew
exec zsh -l
```

The installer backs up existing files before linking `.zshrc`, `.zprofile`, and
the Ruff fallback into their standard locations. Omit `--brew` to install only
the configuration links.

## Homebrew packages

The deliberately small `Brewfile` installs:

- Ruff and uv
- zsh-autosuggestions
- zsh-completions
- zsh-syntax-highlighting

Install or reconcile it independently with:

```sh
brew bundle --file ~/.config/zsh-config/Brewfile --no-upgrade
```

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
