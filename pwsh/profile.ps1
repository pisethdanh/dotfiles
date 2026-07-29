# Starship prompt — separate theme from zsh (see starship/starship-pwsh.toml),
# so it's visually obvious which shell a pane is running.
$env:STARSHIP_CONFIG = "$HOME/.config/starship-pwsh.toml"
Invoke-Expression (&starship init powershell)

# PSReadLine: inline predictive history (zsh-autosuggestions equivalent) +
# menu-style Tab completion.
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
Set-PSReadLineOption -Colors @{ InlinePrediction = "$([char]0x1b)[38;5;245m" }
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# fzf-powered fuzzy completion + history search — mirrors the zsh fzf-tab /
# fzf Ctrl-T/Ctrl-R setup.
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Set-PsFzfOption -TabExpansion
}

# eza-backed ls, matching the zsh aliases. ll/la/lt bake in flags, and
# Set-Alias can't attach arguments, so those stay functions; plain `ls` is a
# straight 1:1 mapping so Set-Alias works.
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias -Name ls -Value eza
    function ll { eza -l @args }
    function la { eza -la @args }
    function lt { eza --tree @args }
}

# Infra tooling, matching the zsh aliases.
if (Get-Command istioctl -ErrorAction SilentlyContinue) { Set-Alias -Name ic -Value istioctl }
if (Get-Command kubectl -ErrorAction SilentlyContinue) { Set-Alias -Name k -Value kubectl }
if (Get-Command terraform -ErrorAction SilentlyContinue) { Set-Alias -Name tf -Value terraform }
if (Get-Command terragrunt -ErrorAction SilentlyContinue) { Set-Alias -Name tg -Value terragrunt }

# Machine-local additions, mirroring how ~/.zshrc reads ~/.config/zsh/*.zsh:
# every *.ps1 in conf.d is dot-sourced, in name order, after everything above —
# so it can override these defaults. That directory is untracked, which is where
# per-repo workflows and anything secret-adjacent belong: install.sh relinks
# $PROFILE on every run, and nothing in conf.d is affected by that.
$ConfD = "$HOME/.config/powershell/conf.d"
if (Test-Path $ConfD) {
    foreach ($f in Get-ChildItem -Path $ConfD -Filter '*.ps1' | Sort-Object Name) {
        . $f.FullName
    }
}
