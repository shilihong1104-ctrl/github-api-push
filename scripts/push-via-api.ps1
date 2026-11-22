<#
.SYNOPSIS
  Push files to a GitHub repo via the Contents API, bypassing `git push`.
.DESCRIPTION
  Use when `git push` fails (github.com unreachable) but api.github.com works.
  Reads a CSV of remote->local mappings; creates or updates each file.
  The token is never printed. Existing files are detected and updated with sha.
.PARAMETER Owner
  GitHub owner (user or org).
.PARAMETER Repo
  Repository name.
.PARAMETER Branch
  Target branch. Default: main
.PARAMETER ItemsFile
  CSV with columns remote,local (one file per row). Default: push-items.csv in cwd.
.PARAMETER Message
  Commit message applied to every file PUT.
.PARAMETER DryRun
  Print planned actions without calling the API.
#>
param(
  [Parameter(Mandatory = $true)][string]$Owner,
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Branch = "main",
  [string]$ItemsFile = "push-items.csv",
  [Parameter(Mandatory = $true)][string]$Message,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# --- obtain token without printing it (here-string feeds clean lines to git) ---
$credInput = @"
protocol=https
host=github.com
"@
$credLines = $credInput | git credential fill 2>$null
$token = ($credLines | ForEach-Object { if ($_ -match '^password=(.*)$') { $matches[1] } }) | Select-Object -First 1
if (-not $token) { throw "No GitHub token found in credential store. Cache one via 'git push' or set a PAT." }

$headers = @{
  Authorization = "token $token"
  "User-Agent"  = "trae-skill"
  Accept        = "application/vnd.github+json"
}
$base = "https://api.github.com/repos/$Owner/$Repo/contents"

if (-not (Test-Path $ItemsFile)) { throw "Items file not found: $ItemsFile" }
$items = Import-Csv -Path $ItemsFile
if (-not $items -or $items.Count -eq 0) { throw "Items file is empty: $ItemsFile" }

foreach ($item in $items) {
  $remote = $item.remote.Trim()
  $local  = $item.local.Trim()
  if (-not $remote -or -not $local) { Write-Output "SKIP (empty row)"; continue }
  if (-not (Test-Path $local)) { Write-Output "FAIL: $remote -> local missing: $local"; continue }

  $bytes  = [System.IO.File]::ReadAllBytes($local)
  $b64    = [Convert]::ToBase64String($bytes)
  $sizeKb = [math]::Round($bytes.Length / 1KB, 1)

  if ($DryRun) {
    Write-Output "[dry-run] would PUT $remote ($sizeKb KB) <- $local"
    continue
  }

  $obj = @{ message = $Message; content = $b64; branch = $Branch }
  try {
    $existing = Invoke-RestMethod -Uri "$base/$remote`?ref=$Branch" -Headers $headers -TimeoutSec 20
    $obj.sha = $existing.sha
    $op = "update"
  } catch {
    $op = "create"
  }

  $json      = $obj | ConvertTo-Json -Compress
  $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  try {
    Invoke-RestMethod -Uri "$base/$remote" -Method Put -Headers $headers -Body $bodyBytes -ContentType "application/json" -TimeoutSec 40 | Out-Null
    Write-Output "OK  ($op): $remote ($sizeKb KB)"
  } catch {
    Write-Output "FAIL: $remote -> $($_.Exception.Message)"
  }
}
Write-Output "DONE"
