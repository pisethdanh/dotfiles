# dotfiles

macOS terminal setup: [Ghostty](https://ghostty.org) + [zinit](https://github.com/zdharma-continuum/zinit) + [Starship](https://starship.rs), themed with [Catppuccin Mocha](https://catppuccin.com).

## Setup (new machine)

```sh
curl -fsSL https://raw.githubusercontent.com/pisethdanh/dotfiles/main/install.sh | bash
```

No manual clone needed — the script clones itself to `~/code/dotfiles` first if
it's not already there. Equivalently, clone it yourself and run it locally:

```sh
git clone https://github.com/pisethdanh/dotfiles.git ~/code/dotfiles
~/code/dotfiles/install.sh
```

Re-running `install.sh` is safe — it's idempotent, and any real file it would
overwrite gets backed up (`<file>.bak.<timestamp>`) instead of deleted.

## What it installs

Also installs Homebrew itself if missing, and prompts for the Xcode Command
Line Tools (required for `git`/`brew`) if they aren't already present.

### Via Homebrew

| Tool | Description |
| --- | --- |
| [atuin](https://github.com/atuinsh/atuin) | Searchable, SQLite-backed shell history (replaces Ctrl-R). |
| [Azure CLI](https://github.com/Azure/azure-cli) | Command-line tool for managing Azure resources. |
| [Colima](https://github.com/abiosoft/colima) | Container runtimes on macOS with minimal setup, as a Docker Desktop alternative. |
| [Docker CLI](https://github.com/docker/cli) | Docker command-line client, used against the Colima runtime. |
| [eza](https://github.com/eza-community/eza) | Modern, maintained replacement for `ls`. |
| [fnm](https://github.com/Schniz/fnm) | Fast, Rust-based Node.js version manager. Also installs Node LTS. |
| [fzf](https://github.com/junegunn/fzf) | General-purpose command-line fuzzy finder; provides the Ctrl-T/Alt-C key bindings. |
| [Ghostty](https://github.com/ghostty-org/ghostty) | GPU-accelerated terminal emulator. |
| [Helm](https://github.com/helm/helm) | Package manager for Kubernetes. |
| [kubectl](https://github.com/kubernetes/kubectl) | Kubernetes command-line tool. |
| [kubectx](https://github.com/ahmetb/kubectx) | Fast switching between kubectl contexts (`kubectx`) and namespaces (`kubens`). |
| [kubelogin](https://github.com/Azure/kubelogin) | kubectl credential plugin for Azure AD login to AKS clusters. |
| [Starship](https://github.com/starship/starship) | Fast, minimal, customizable prompt for any shell. |
| [Terraform](https://github.com/hashicorp/terraform) | Infrastructure-as-code provisioning tool. |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Thin wrapper for keeping Terraform configurations DRY. |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` — jumps to frecent directories via `z`. |

`install.sh` only installs the Colima/Docker CLIs — it doesn't start the VM.
Run `colima start` once to bring up the container runtime before using `docker`.

### Via zinit (zsh plugins)

| Tool | Description |
| --- | --- |
| [zinit](https://github.com/zdharma-continuum/zinit) | The zsh plugin manager itself — supports turbo-mode async loading. |
| [fzf-tab](https://github.com/Aloxaf/fzf-tab) | Replaces zsh's tab-completion menu with an fzf-powered fuzzy one. |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like grey "ghost text" suggestions from history as you type. |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Fish-like syntax highlighting for commands as you type. |

## Layout

| Path                        | Symlinked to                                                          |
| ---------------------------- | ---------------------------------------------------------------------- |
| `zsh/zshrc`                  | `~/.zshrc`                                                              |
| `zsh/aliases.zsh`             | `~/.config/zsh/aliases.zsh`                                             |
| `zsh/path.zsh`                | `~/.config/zsh/path.zsh`                                                |
| `starship/starship.toml`      | `~/.config/starship.toml`                                               |
| `ghostty/config.ghostty`      | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`    |

`~/.zshrc` sources every `*.zsh` file in `~/.config/zsh/` — drop a new file
there for more aliases/exports without editing `.zshrc` itself.

`zsh/exports.zsh.example` is a template for `~/.config/zsh/exports.zsh`, which
holds real secrets (e.g. `NUGET_AUTH_TOKEN`) and is deliberately **not**
tracked by git (see `.gitignore`). `install.sh` copies the template on first
run if the real file doesn't exist yet — fill in actual values after that.
