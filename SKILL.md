---
name: github-api-push
description: Push files to GitHub via the Contents API when git push fails on network. Use when git push times out or cannot connect to github.com but files must reach the remote. Do not use when api.github.com is also unreachable.
---

# GitHub API Push

When `git push` fails (connection timeout / port 443 unreachable on `github.com`) but a commit must reach the remote, fall back to the GitHub **Contents API**. In this workspace `api.github.com` is typically reachable even when the `github.com` git endpoint is not.

## When to trigger
- `git push` returns `Failed to connect to github.com port 443` or times out after ~20s
- You need to create or update files in a GitHub repo you own

## Prerequisites (verify first)
- A cached GitHub credential (PAT) in Windows Credential Manager — confirm reachability and that `git credential fill` returns a password.
- `api.github.com` reachable: `Invoke-WebRequest https://api.github.com -UseBasicParsing -TimeoutSec 8` returns 200.

If `api.github.com` is also down, this skill cannot help — report the network state and wait for recovery. Do not claim the push succeeded.

## Procedure
1. Obtain the token **without printing it** (the script does this; never echo `$token`).
2. For each file:
   - **New file** → `PUT /repos/{owner}/{repo}/contents/{path}` with `{message, content(base64), branch}`.
   - **Existing file** → first `GET .../contents/{path}?ref={branch}` to read `sha`, then `PUT` with `sha` added.
3. Encode the JSON body as **UTF-8 bytes** before sending, so Chinese filenames/content do not mojibake.
4. Verify each file remotely: `GET .../contents/{path}` and confirm size/name.

## Security
- Never print the token to output. Capture into a variable only.
- This only creates/updates files — never delete repos, change settings, or force-push.

## Script
Use `scripts/push-via-api.ps1`. It auto-detects new vs existing files, handles UTF-8, and supports `-DryRun`.

### Usage
1. Write a CSV `push-items.csv` with two columns `remote,local` (one file per row; local paths may be relative or absolute).
2. Call the script **in-process** with `&` in the current shell:
   ```powershell
   & "d:\temp_20261120_01\.trae\skills\github-api-push\scripts\push-via-api.ps1" `
     -Owner <owner> -Repo <repo> -Branch main `
     -ItemsFile push-items.csv -Message "feat: ..."
   ```
   Do **not** launch it via `powershell.exe -File` or `-Command` — in this environment a child process breaks the stdin pipe to `git credential fill`, which fails with `missing protocol field`. The script must run in the current process.
3. Add `-DryRun` first to preview without touching the remote.
4. If the execution policy blocks `.ps1`, run `Set-ExecutionPolicy -Scope Process Bypass` first (current process only, reverts on exit, does not change machine policy), then retry the `&` call.

### CSV example
```csv
remote,local
training/config.py,D:\proj\training\config.py
README.md,D:\proj\README.md
```
