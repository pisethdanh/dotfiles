#!/usr/bin/env bash
# Bootstraps a macOS machine with this repo's terminal setup: Homebrew, Ghostty,
# zinit + zsh plugins, Starship, and the CLI tools the zsh config expects.
# Safe to re-run — every step is idempotent and existing real files are backed
# up (not deleted) before being replaced with symlinks.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

link_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    local backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    info "Backed up existing $dest -> $backup"
  fi
  ln -s "$src" "$dest"
  info "Linked $dest -> $src"
}

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This install script is macOS-only." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools (follow the GUI prompt, then re-run this script)"
  xcode-select --install
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

info "Installing Ghostty"
brew install --cask ghostty

info "Installing CLI tools (starship, fzf, zoxide, eza, atuin, fnm, kubectl, terragrunt)"
brew install starship fzf zoxide eza atuin fnm kubernetes-cli terragrunt

info "Installing Terraform (HashiCorp's own tap — no longer in homebrew-core)"
brew install hashicorp/tap/terraform

ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  info "Installing zinit"
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

info "Installing Node LTS via fnm"
fnm install --lts
fnm default lts-latest

info "Linking dotfiles"
link_file "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/aliases.zsh" "$HOME/.config/zsh/aliases.zsh"
link_file "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
link_file "$DOTFILES_DIR/ghostty/config.ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

EXPORTS="$HOME/.config/zsh/exports.zsh"
if [ ! -e "$EXPORTS" ]; then
  info "Creating $EXPORTS from template — edit it to fill in real secrets"
  mkdir -p "$(dirname "$EXPORTS")"
  cp "$DOTFILES_DIR/zsh/exports.zsh.example" "$EXPORTS"
fi

info "Done. Open a new terminal tab (or: exec zsh) to pick everything up."
