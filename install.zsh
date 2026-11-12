#!/bin/zsh

set -eu

repo_dir="${0:A:h}"
target="$HOME/.zshrc"
local_dir="$HOME/.config/zsh"

mkdir -p "$local_dir"

if [[ -L "$target" && "${target:A}" == "$repo_dir/.zshrc" ]]; then
  print "Already installed: $target -> $repo_dir/.zshrc"
elif [[ -e "$target" || -L "$target" ]]; then
  backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
  mv "$target" "$backup"
  ln -s "$repo_dir/.zshrc" "$target"
  print "Backed up the previous config to $backup"
  print "Installed: $target -> $repo_dir/.zshrc"
else
  ln -s "$repo_dir/.zshrc" "$target"
  print "Installed: $target -> $repo_dir/.zshrc"
fi

if [[ ! -e "$local_dir/local.zsh" ]]; then
  cp "$repo_dir/local.zsh.example" "$local_dir/local.zsh"
  chmod 600 "$local_dir/local.zsh"
  print "Created private local config: $local_dir/local.zsh"
fi

print "Restart the shell with: exec zsh"
