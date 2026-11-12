# Zsh config

A small, portable Zsh configuration for macOS and Linux. It includes:

- Git branch and dirty-state information in the prompt
- Previous-command timing
- Completions, autosuggestions, and syntax highlighting when installed
- A private, per-machine override file outside the repository

## Homebrew plugins

macOS already includes Zsh. Install the three optional plugins with:

```sh
brew install zsh-autosuggestions zsh-completions zsh-syntax-highlighting
```

The config detects Homebrew in the standard Apple Silicon, Intel macOS, and
Linuxbrew locations. It still works if Homebrew or the plugins are unavailable.

## Install

Clone the public repository over HTTPS, so the work Mac does not need a GitHub
login or SSH key:

```sh
git clone https://github.com/njf0/zsh-config.git ~/.config/zsh-config
~/.config/zsh-config/install.zsh
exec zsh
```

The installer backs up an existing `~/.zshrc` before linking this config.

## Private or machine-specific configuration

Put private values and work-specific paths in:

```text
~/.config/zsh/local.zsh
```

This file is outside the repository. Do not put API keys or other credentials in
the public checkout, even if their filenames appear in `.gitignore`.
