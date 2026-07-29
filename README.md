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

Individual install steps are also non-fatal: if one fails (an app or font
already installed by hand, a tap that's down, no network) the script warns,
keeps going, and lists everything that failed at the end.

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
| [istioctl](https://github.com/istio/istio) | CLI for configuring and debugging an Istio service mesh (aliased to `ic`). |
| [jq](https://github.com/jqlang/jq) | Command-line JSON processor. |
| [kubectl](https://github.com/kubernetes/kubectl) | Kubernetes command-line tool (aliased to `k`). |
| [kubectx](https://github.com/ahmetb/kubectx) | Fast switching between kubectl contexts (`kubectx`) and namespaces (`kubens`). |
| [kubelogin](https://github.com/Azure/kubelogin) | kubectl credential plugin for Azure AD login to AKS clusters. |
| [Starship](https://github.com/starship/starship) | Fast, minimal, customizable prompt for any shell. |
| [Terraform](https://github.com/hashicorp/terraform) | Infrastructure-as-code provisioning tool (aliased to `tf`). |
| [Terragrunt](https://github.com/gruntwork-io/terragrunt) | Thin wrapper for keeping Terraform configurations DRY (aliased to `tg`). |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` — jumps to frecent directories via `z`. |

`install.sh` starts Colima for you as its last step, so `docker` works straight
after a fresh install. The VM is only created once — later runs skip the step if
it's already up, and start it without touching its configuration if it isn't.

Colima's own defaults (2 CPU / 2GiB) are thin for a Kubernetes workload, so a
newly created VM gets half the host's cores and a third of its RAM. Override
with `COLIMA_CPUS=8 COLIMA_MEMORY=12 ./install.sh`, or resize later with
`colima stop && colima start --cpus 8 --memory 12`. Sizing only applies when the
VM is created — an existing one keeps whatever it was built with.

### Via zinit (zsh plugins)

| Tool | Description |
| --- | --- |
| [zinit](https://github.com/zdharma-continuum/zinit) | The zsh plugin manager itself — supports turbo-mode async loading. |
| [fzf-tab](https://github.com/Aloxaf/fzf-tab) | Replaces zsh's tab-completion menu with an fzf-powered fuzzy one. |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like grey "ghost text" suggestions from history as you type. |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Fish-like syntax highlighting for commands as you type. |

## Layout

| Path | Symlinked to |
| --- | --- |
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/aliases.zsh` | `~/.config/zsh/aliases.zsh` |
| `zsh/path.zsh` | `~/.config/zsh/path.zsh` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `ghostty/config.ghostty` | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| `pwsh/profile.ps1` | pwsh's `$PROFILE` (only when `pwsh` is installed) |
| `starship/starship-pwsh.toml` | `~/.config/starship-pwsh.toml` (same condition) |

`~/.zshrc` sources every `*.zsh` file in `~/.config/zsh/` — drop a new file
there for more aliases/exports without editing `.zshrc` itself.

`zsh/exports.zsh` holds environment variables for secrets/tokens (e.g.
`NUGET_AUTH_TOKEN`), all commented out. `install.sh` **copies** it to
`~/.config/zsh/exports.zsh` on first run if that file doesn't exist yet — a
copy rather than a symlink so real values live outside the repo and can't be
committed by accident. Nothing needs filling in for a working shell; uncomment
a line in the copy if and when you need it.

### If those files already exist

Everything in the table above is repo-owned, so `install.sh` **replaces** it on
every run — the symlink is how a `git pull` reaches your shell. Nothing is
thrown away silently:

| Already at the target | What `install.sh` does |
| --- | --- |
| A real file or directory | Moves it to `<file>.bak.<timestamp>`, then symlinks. |
| A symlink into this repo | Recreates it — a no-op, and stays quiet about it. |
| A symlink pointing elsewhere | Recreates it, logging the old target first (the file it pointed at is untouched). |

`~/.config/zsh/exports.zsh` is the one exception: it's yours, not the repo's, so
once it exists `install.sh` leaves it alone entirely — never overwritten, never
backed up. Your secrets survive every re-run. The trade-off is that new lines
added to `zsh/exports.zsh` later don't reach machines that already have the
copy; add those by hand.

### Machine-local pwsh config

`$PROFILE` is a symlink to `pwsh/profile.ps1`, so it gets replaced on every run
— don't edit it in place. Instead, drop a `*.ps1` file in
`~/.config/powershell/conf.d/` (untracked; `install.sh` creates the directory
but never writes to it). The profile dot-sources everything in there in name
order, after its own defaults, so those files can override them. It's the pwsh
counterpart to `~/.config/zsh/*.zsh`.

That's where per-repo workflows and anything credential-adjacent belong: a
relink can't touch them, and they can't end up committed here.

`pwsh/entra.ps1` is installed into that directory as a symlink, so it updates
with a `git pull` like everything else:

| Command | |
| --- | --- |
| `Add-EntraTenant -User admin@<tenant>.onmicrosoft.com` | Onboard a tenant: looks the tenant id up from the domain, prompts for the password, stores it in the login keychain |
| `Get-EntraTenant` | List configured tenants and whether each password is stored |
| `Remove-EntraTenant -Name <name>` | Drop one (keeps the keychain password unless `-IncludeSecret`) |
| `setenv [-Tenant <name>]` | Point the **current git repo** at a tenant: sets the configured environment variables and rewrites the configured dotenv keys |

The target is always the repo you're standing in — resolved via `git rev-parse
--show-toplevel` rather than a configured path — so worktrees and second clones
work with no extra setup.

`entra.ps1` itself is generic: it knows how to onboard a tenant and substitute
values, but not what any project calls them. That mapping lives in
`~/.config/entra/tenants.json` under `apply`, which names the variables to set,
the dotenv file to rewrite and an optional per-repo script to run first. Values
are templates over `{user}`, `{password}`, `{tenantId}` and `{name}`:

```json
"apply": {
  "envFile": ".env",
  "env":  { "AZURE_USER": "{user}", "AZURE_TENANT_ID": "{tenantId}" },
  "file": { "AZURE_USER": "{user}", "AZURE_PASSWORD": "{password}" }
}
```

`install.sh` **copies** that file from `pwsh/tenants.json` on first run and then
never touches it — same copy-not-symlink reasoning as `exports.zsh`. It ships
with an empty `apply`, so no project's variable names end up in this repo.

#### Passwords in the keychain

Passwords are never in `tenants.json`. They go to the login keychain under
service `entra`, keyed on the account's UPN — unique by construction, so there's
no invented name to collide or drift out of sync with the tenant it belongs to.

`Add-EntraTenant` and `Remove-EntraTenant -IncludeSecret` manage them. To audit
or fix one up by hand, `security` does the same job. There's no flag to filter
items by service, hence the `awk` — this lists every account with a stored
password:

```sh
security dump-keychain | awk '/"acct"<blob>=/{a=$0} /"svce"<blob>="entra"/{print a}'
```

Then read, store/update, or delete a single one:

```sh
security find-generic-password -s entra -a 'admin@contoso.onmicrosoft.com' -w
security add-generic-password -U -s entra -a 'admin@contoso.onmicrosoft.com' -w
security delete-generic-password -s entra -a 'admin@contoso.onmicrosoft.com'
```

`-w` with no value prompts for the password twice to confirm, so it never lands
in shell history; `-U` updates an existing entry instead of failing on it.
Keychain Access.app searched for `entra` shows the same items if you'd rather
click. A missing entry is what makes `Get-EntraTenant` report `MISSING` for a
tenant that's otherwise configured.