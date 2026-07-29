#!/usr/bin/env bash
# Bootstraps a macOS machine with this repo's terminal setup: Homebrew, Ghostty,
# zinit + zsh plugins, Starship, and the CLI tools the zsh config expects.
# Safe to re-run — every step is idempotent and existing real files are backed
# up (not deleted) before being replaced with symlinks.
#
# Runnable two ways:
#   curl -fsSL https://raw.githubusercontent.com/pisethdanh/dotfiles/main/install.sh | bash
#   (or) git clone https://github.com/pisethdanh/dotfiles.git ~/code/dotfiles && ~/code/dotfiles/install.sh
# Either way this repo ends up cloned to $DOTFILES_DIR below.
set -euo pipefail

DOTFILES_REPO="https://github.com/pisethdanh/dotfiles.git"
DOTFILES_DIR="$HOME/code/dotfiles"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }

# Newline-delimited list of steps that failed, reported in the closing summary.
FAILED_STEPS=""

# Runs a step whose failure shouldn't sink the whole install (a cask that
# collides with a hand-installed app, a tap that's down, no network). Warns,
# records the step, and always succeeds so `set -e` doesn't abort the run.
try_step() {
  local label="$1"
  shift
  if ! "$@"; then
    warn "$label failed — continuing with the rest of the install"
    FAILED_STEPS+="  - $label"$'\n'
  fi
  return 0
}

# `brew install --cask` errors out (rather than no-oping) when the app or font
# is already on disk but wasn't installed by brew — e.g. a font dragged into
# Font Book, or an app dropped straight into /Applications. --force adopts what
# is already there instead of failing.
install_cask() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    info "$cask already installed — skipping"
    return 0
  fi
  info "Installing $cask"
  try_step "$cask" brew install --cask --force "$cask"
}

link_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    local current
    current="$(readlink "$dest")"
    # Only worth reporting when it pointed elsewhere — e.g. a link left by
    # another dotfiles manager — since that target is otherwise lost silently.
    # Re-runs of our own links stay quiet.
    [ "$current" = "$src" ] || info "Replacing symlink $dest (was -> $current)"
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

if [ ! -d "$DOTFILES_DIR/.git" ]; then
  info "Cloning dotfiles to $DOTFILES_DIR"
  mkdir -p "$(dirname "$DOTFILES_DIR")"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

install_cask ghostty
install_cask font-jetbrains-mono-nerd-font

CLI_TOOLS=(
  atuin
  azure-cli
  Azure/kubelogin/kubelogin          # Azure's own tap — not the homebrew-core int128/kubelogin
  colima
  docker
  eza
  fnm
  fzf
  hashicorp/tap/terraform            # HashiCorp's own tap — no longer in homebrew-core
  helm
  istioctl
  jq
  kubectx
  kubernetes-cli
  starship
  terragrunt
  zoxide
)

info "Installing CLI tools (${CLI_TOOLS[*]})"
if ! brew install "${CLI_TOOLS[@]}"; then
  # A single unavailable formula or tap fails the whole batch, so fall back to
  # one-at-a-time to get everything that *can* install rather than none of it.
  warn "Batch install failed — retrying each tool individually"
  for tool in "${CLI_TOOLS[@]}"; do
    try_step "$tool" brew install "$tool"
  done
fi

ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
  info "Installing zinit"
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

info "Installing Node LTS via fnm"
try_step "Node LTS via fnm" bash -c 'fnm install --lts && fnm default lts-latest'

info "Linking dotfiles"
link_file "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/aliases.zsh" "$HOME/.config/zsh/aliases.zsh"
link_file "$DOTFILES_DIR/zsh/path.zsh" "$HOME/.config/zsh/path.zsh"
link_file "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
link_file "$DOTFILES_DIR/ghostty/config.ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

if command -v pwsh >/dev/null 2>&1; then
  link_file "$DOTFILES_DIR/starship/starship-pwsh.toml" "$HOME/.config/starship-pwsh.toml"
  link_file "$DOTFILES_DIR/pwsh/profile.ps1" "$(pwsh -NoProfile -Command 'Write-Output $PROFILE')"
  # Machine-local pwsh config the profile dot-sources; never populated by this
  # script, so anything dropped in there survives a relink.
  mkdir -p "$HOME/.config/powershell/conf.d"
  info "Installing PSFzf (pwsh fuzzy completion)"
  try_step "PSFzf" pwsh -NoProfile -Command "Install-Module -Name PSFzf -Scope CurrentUser -Repository PSGallery -Force"
fi

# Copied rather than symlinked: this is where real secrets go, so it has to live
# outside the repo. Everything in it ships commented out, so a fresh install is
# complete without touching it.
# -L as well as -e: a dangling symlink is invisible to -e, and cp would follow it
# and write the template through to wherever it points.
EXPORTS="$HOME/.config/zsh/exports.zsh"
if [ ! -e "$EXPORTS" ] && [ ! -L "$EXPORTS" ]; then
  info "Creating $EXPORTS — uncomment a line in it if/when you need that token"
  mkdir -p "$(dirname "$EXPORTS")"
  cp "$DOTFILES_DIR/zsh/exports.zsh" "$EXPORTS"
fi

if [ -n "$FAILED_STEPS" ]; then
  warn "Finished, but these steps failed and need a look:"
  printf '%s' "$FAILED_STEPS" >&2
  warn "Everything else was installed. Re-run this script after fixing them."
fi

info "Done. Open a new terminal tab (or: exec zsh) to pick everything up."
