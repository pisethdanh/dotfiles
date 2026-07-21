# dotfiles

macOS terminal setup: [Ghostty](https://ghostty.org) + [zinit](https://github.com/zdharma-continuum/zinit) + [Starship](https://starship.rs), themed with [Catppuccin Mocha](https://catppuccin.com).

## Setup (new machine)

```sh
git clone <this-repo-url> ~/code/dotfiles
cd ~/code/dotfiles
./install.sh
```

Re-running `install.sh` is safe — it's idempotent, and any real file it would
overwrite gets backed up (`<file>.bak.<timestamp>`) instead of deleted.

## What it installs

- Homebrew (if missing) + Xcode Command Line Tools prompt
- Ghostty, Starship, zinit
- fzf, zoxide, eza, atuin, fnm, kubectl, terraform, terragrunt
- Node LTS via fnm

## Layout

| Path                        | Symlinked to                                                          |
| ---------------------------- | ---------------------------------------------------------------------- |
| `zsh/zshrc`                  | `~/.zshrc`                                                              |
| `zsh/aliases.zsh`             | `~/.config/zsh/aliases.zsh`                                             |
| `starship/starship.toml`      | `~/.config/starship.toml`                                               |
| `ghostty/config.ghostty`      | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`    |

`~/.zshrc` sources every `*.zsh` file in `~/.config/zsh/` — drop a new file
there for more aliases/exports without editing `.zshrc` itself.

`zsh/exports.zsh.example` is a template for `~/.config/zsh/exports.zsh`, which
holds real secrets (e.g. `NUGET_AUTH_TOKEN`) and is deliberately **not**
tracked by git (see `.gitignore`). `install.sh` copies the template on first
run if the real file doesn't exist yet — fill in actual values after that.
