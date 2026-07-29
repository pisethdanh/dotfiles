# Entra ID tenant credentials for local development.
#
# Onboards a tenant — identity in JSON, password in the login keychain — and then
# points whatever git repo you're standing in at it, by setting environment
# variables and rewriting matching keys in a dotenv file.
#
# This file is generic on purpose. Which variables get set, which file gets
# rewritten and which script runs first are all configured in $EntraConfigPath,
# not here, so nothing about any particular project lives in this repo.
#
#   Add-EntraTenant -User admin@<tenant>.onmicrosoft.com   onboard (one command)
#   Get-EntraTenant                                        list what's configured
#   Remove-EntraTenant -Name <name>                        drop one
#   setenv [-Tenant <name>]                                apply to this repo
#
# Nothing runs at shell startup, and no path is hardcoded — the target is always
# the current repository root, so worktrees and second clones need no setup.
$EntraKeychainService = 'entra'
$EntraConfigPath      = "$HOME/.config/entra/tenants.json"

# Reports a failure to a human.
#
# Deliberately Write-Host rather than Write-Error: the ConciseView error format
# prints a file/line header with squiggles and wraps the message body, prefixing
# every continuation line with '|'. That shreds any command you'd want to copy
# out of the message. These are interactive helpers, so a clean unwrapped line
# beats being catchable — $Command is printed alone, on one line, unindented, so
# a double-click or triple-click selects exactly the thing you need to run.
function Write-EntraError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Command
    )

    Write-Host "entra: $Message" -ForegroundColor Red
    if ($Command) {
        Write-Host ''
        Write-Host $Command -ForegroundColor Yellow
        Write-Host ''
    }
}

# ---------------------------------------------------------------- tenant store

# Read fresh on every call rather than cached in a variable at load time, so a
# tenant added mid-session is usable immediately — including in tab completion.
function Get-EntraConfig {
    if (-not (Test-Path $EntraConfigPath)) {
        return @{ default = $null; tenants = @{}; apply = @{} }
    }
    $cfg = Get-Content -Raw -LiteralPath $EntraConfigPath | ConvertFrom-Json -AsHashtable
    if ($null -eq $cfg)         { $cfg = @{} }
    if ($null -eq $cfg.tenants) { $cfg.tenants = @{} }
    if ($null -eq $cfg.apply)   { $cfg.apply = @{} }
    $cfg
}

function Save-EntraConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)

    $dir = Split-Path -Parent $EntraConfigPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $EntraConfigPath
}

# Resolves a tenant GUID from its domain via the public OIDC discovery document,
# so onboarding doesn't need a trip to the portal. Nothing secret is sent — the
# document is anonymous — but it does need network.
function Get-EntraTenantId {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Domain)

    $url = "https://login.microsoftonline.com/$Domain/v2.0/.well-known/openid-configuration"
    try {
        $issuer = (Invoke-RestMethod -Uri $url -TimeoutSec 15 -ErrorAction Stop).issuer
    } catch {
        Write-EntraError "couldn't look up a tenant id for '$Domain' ($($_.Exception.Message)). Pass it yourself:" `
            'Add-EntraTenant -User <upn> -TenantId <guid>'
        return $null
    }
    if ($issuer -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
        return $matches[1]
    }
    Write-EntraError "no tenant id in the discovery document for '$Domain'. Pass it yourself:" `
        'Add-EntraTenant -User <upn> -TenantId <guid>'
    $null
}

function Test-EntraSecret {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Account)

    security find-generic-password -s $EntraKeychainService -a $Account -w *> $null
    $LASTEXITCODE -eq 0
}

function Get-KeychainSecret {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Service,
        # The account the password belongs to — here the full AAD UPN, which is
        # unique by construction, rather than a name we invent.
        [Parameter(Mandatory)][string]$Account
    )

    $value = security find-generic-password -s $Service -a $Account -w 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        Write-EntraError "no keychain password stored for '$Account'. Store it once with:" `
            "security add-generic-password -s $Service -a '$Account' -w"
        return $null
    }
    $value
}

function Add-EntraTenant {
    [CmdletBinding()]
    param(
        # Full UPN, e.g. admin@contoso.onmicrosoft.com
        [Parameter(Mandatory)][string]$User,
        # Looked up from the domain when omitted.
        [string]$TenantId,
        # Short name you'll pass to -Tenant. Defaults to the domain's first
        # label, which is what actually identifies the tenant.
        [string]$Name,
        # Normally left off, so you get prompted. Accepts a SecureString for
        # scripted use — see the stdin guard below for why that matters.
        [System.Security.SecureString]$Password,
        [switch]$SetDefault
    )

    if ($User -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
        Write-EntraError "'$User' doesn't look like a UPN — expected user@domain.tld."
        return
    }
    $domain = $User.Split('@')[-1]
    if (-not $Name) { $Name = ($domain -split '\.')[0].ToLowerInvariant() }

    if (-not $TenantId) {
        Write-Host "looking up tenant id for $domain ..." -ForegroundColor DarkGray
        $TenantId = Get-EntraTenantId $domain
        if (-not $TenantId) { return }   # already explained how to fix it
    }

    # Read without echo, then hand it to `security` on stdin — which wants the
    # value twice, once to confirm. Deliberately not passed as an argument: argv
    # is visible to any `ps` while the process lives.
    if (-not $Password) {
        # Read-Host -AsSecureString does not fall back to stdin: with input
        # redirected it terminates the whole script at the prompt, silently and
        # with exit 0. Refuse up front instead of vanishing mid-way.
        if ([Console]::IsInputRedirected) {
            Write-EntraError 'stdin is not a terminal, so the password prompt would silently abort. Pass one:' `
                'Add-EntraTenant -User <upn> -Password (Read-Host -AsSecureString)'
            return
        }
        $Password = Read-Host "Password for $User" -AsSecureString
    }
    if ($Password.Length -eq 0) {
        Write-EntraError 'no password entered; nothing was stored.'
        return
    }
    $plain = [System.Net.NetworkCredential]::new('', $Password).Password
    "$plain`n$plain" | security add-generic-password -U -s $EntraKeychainService -a $User -w *> $null
    $storeFailed = $LASTEXITCODE -ne 0
    $plain = $null
    if ($storeFailed) {
        Write-EntraError "keychain refused to store the password for '$User'."
        return
    }

    $cfg = Get-EntraConfig
    $isNew = -not $cfg.tenants.ContainsKey($Name)
    $cfg.tenants[$Name] = @{ user = $User; tenantId = $TenantId }
    # First tenant onboarded becomes the default; nothing else to decide.
    if ($SetDefault -or -not $cfg.default) { $cfg.default = $Name }
    Save-EntraConfig $cfg

    Write-Host "$(if ($isNew) { 'added' } else { 'updated' }) tenant '$Name'  $User  $TenantId" -ForegroundColor Green
    if ($cfg.default -eq $Name) { Write-Host '  (default)' -ForegroundColor DarkGray }
}

function Get-EntraTenant {
    [CmdletBinding()]
    param()

    $cfg = Get-EntraConfig
    if ($cfg.tenants.Count -eq 0) {
        Write-EntraError 'no tenants configured yet. Add one with:' `
            'Add-EntraTenant -User admin@<tenant>.onmicrosoft.com'
        return
    }
    foreach ($name in $cfg.tenants.Keys | Sort-Object) {
        $t = $cfg.tenants[$name]
        [pscustomobject]@{
            Default  = if ($name -eq $cfg.default) { '*' } else { '' }
            Name     = $name
            User     = $t.user
            TenantId = $t.tenantId
            Password = if (Test-EntraSecret $t.user) { 'stored' } else { 'MISSING' }
        }
    }
}

function Remove-EntraTenant {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        # Also forget the keychain password. Off by default: dropping a tenant
        # from the list shouldn't quietly destroy a credential.
        [switch]$IncludeSecret
    )

    $cfg = Get-EntraConfig
    if (-not $cfg.tenants.ContainsKey($Name)) {
        Write-EntraError "unknown tenant '$Name'. Known: $($cfg.tenants.Keys -join ', ')"
        return
    }
    $user = $cfg.tenants[$Name].user
    $cfg.tenants.Remove($Name)
    if ($cfg.default -eq $Name) {
        $cfg.default = $cfg.tenants.Keys | Sort-Object | Select-Object -First 1
    }
    Save-EntraConfig $cfg
    Write-Host "removed tenant '$Name'" -ForegroundColor Green
    if ($IncludeSecret) {
        security delete-generic-password -s $EntraKeychainService -a $user *> $null
        Write-Host "  keychain password for $user removed" -ForegroundColor DarkGray
    } else {
        Write-Host "  keychain password for $user kept (-IncludeSecret to remove)" -ForegroundColor DarkGray
    }
    if ($cfg.default) { Write-Host "  default is now '$($cfg.default)'" -ForegroundColor DarkGray }
}

# --------------------------------------------------------------- value plumbing

# Substitutes {user} / {password} / {tenantId} / {name} in a configured template.
#
# Plain .Replace, never -replace: a password containing $1, $& or $_ would be
# eaten by regex substitution syntax, and real passwords do contain $ and #.
function Expand-EntraTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Template,
        [Parameter(Mandatory)][hashtable]$Values
    )

    $out = $Template
    foreach ($key in $Values.Keys) {
        $out = $out.Replace("{$key}", [string]$Values[$key])
    }
    $out
}

# Upserts KEY='value' in a dotenv file.
#
# Appends when the key is absent, where a bare -replace would quietly no-op and
# leave the old value in place.
function Set-EnvFileValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    if ($Value -match "'") {
        Write-Warning "$Key contains a single quote; single-quoted dotenv values can't escape one. Skipped."
        return
    }

    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
    $newLine = "$Key='$Value'"
    $found = $false

    $out = @(foreach ($line in @(Get-Content -LiteralPath $Path)) {
        if ($line -match $pattern) { $found = $true; $newLine } else { $line }
    })
    if (-not $found) { $out += $newLine }

    Set-Content -LiteralPath $Path -Value $out
}

# ------------------------------------------------------------------- the driver

function Set-EntraEnv {
    [CmdletBinding()]
    param(
        # Defaults to the configured default tenant.
        [string]$Tenant,
        # Set the process env vars but leave the dotenv file alone.
        [switch]$SkipEnvFile
    )

    $cfg = Get-EntraConfig
    if (-not $Tenant) { $Tenant = $cfg.default }
    if (-not $Tenant) {
        Write-EntraError 'no tenants configured yet. Add one with:' `
            'Add-EntraTenant -User admin@<tenant>.onmicrosoft.com'
        return
    }
    if (-not $cfg.tenants.ContainsKey($Tenant)) {
        Write-EntraError "unknown tenant '$Tenant'. Known: $($cfg.tenants.Keys -join ', ')"
        return
    }
    $t = $cfg.tenants[$Tenant]

    $apply   = $cfg.apply
    $varMap  = if ($apply.env)  { $apply.env }  else { @{} }
    $fileMap = if ($apply.file) { $apply.file } else { @{} }
    if ($varMap.Count -eq 0 -and $fileMap.Count -eq 0) {
        Write-EntraError "nothing to apply — no 'apply.env' or 'apply.file' entries in $EntraConfigPath." `
            "code $EntraConfigPath"
        return
    }

    # The target is wherever you are, not a configured path — which is what makes
    # this work unchanged in a worktree or a second clone.
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-EntraError 'not inside a git repository.'
        return
    }

    # Fetch the secret before mutating anything, so a missing keychain item
    # leaves the environment as it was rather than half-applied.
    $pw = Get-KeychainSecret -Service $EntraKeychainService -Account $t.user
    if (-not $pw) { return }

    $values = @{ user = $t.user; password = $pw; tenantId = $t.tenantId; name = $Tenant }
    $did = @()

    # A repo's own env script first, so the configured values below win. Invoked
    # rather than dot-sourced because $Env: assignments are process-wide anyway,
    # and it resolves any siblings via its own $PSScriptRoot.
    if ($apply.envScript) {
        $repoScript = Join-Path $repoRoot $apply.envScript
        if (Test-Path $repoScript) {
            & $repoScript
            $did += $apply.envScript
        }
    }

    foreach ($key in $varMap.Keys | Sort-Object) {
        Set-Item -Path "Env:$key" -Value (Expand-EntraTemplate $varMap[$key] $values)
    }
    if ($varMap.Count) { $did += "$($varMap.Count) env vars" }

    if (-not $SkipEnvFile -and $fileMap.Count) {
        $envFileName = if ($apply.envFile) { $apply.envFile } else { '.env' }
        $envFile = Join-Path $repoRoot $envFileName
        if (Test-Path $envFile) {
            foreach ($key in $fileMap.Keys | Sort-Object) {
                Set-EnvFileValue $envFile $key (Expand-EntraTemplate $fileMap[$key] $values)
            }
            $did += "$($fileMap.Count) keys in $envFileName"
        }
    }

    Write-Host "entra -> $Tenant  $($t.user)" -ForegroundColor Green
    Write-Host "  $(Split-Path -Leaf $repoRoot): $($did -join ', ')" -ForegroundColor DarkGray
}

Set-Alias setenv Set-EntraEnv

# Tab-complete tenant names instead of remembering them. Reads the store on each
# invocation, so a freshly added tenant completes without reloading the profile.
$EntraTenantCompleter = {
    param($commandName, $parameterName, $wordToComplete)
    (Get-EntraConfig).tenants.Keys | Sort-Object | Where-Object { $_ -like "$wordToComplete*" }
}
Register-ArgumentCompleter -CommandName Set-EntraEnv -ParameterName Tenant -ScriptBlock $EntraTenantCompleter
Register-ArgumentCompleter -CommandName Remove-EntraTenant -ParameterName Name -ScriptBlock $EntraTenantCompleter
