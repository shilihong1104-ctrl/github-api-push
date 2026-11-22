# github-api-push

A Trae project skill that pushes files to GitHub via the **Contents API** when `git push` fails due to network issues.

## Why
In some environments the `github.com` git endpoint (port 443) is unreachable while `api.github.com` still works. This skill bypasses `git push` and writes files directly through the GitHub Contents API — useful when a commit must reach the remote but `git push` keeps timing out.

## What it does
- Reads a cached GitHub token from Windows Credential Manager (never prints it).
- For each file in a CSV mapping (`remote,local`), creates or updates it on GitHub.
- Auto-detects existing files (fetches `sha`) vs new files.
- Encodes request bodies as UTF-8 so non-ASCII content and filenames do not mojibake.
- Supports `-DryRun` to preview before touching the remote.

## Install
This is a Trae project skill. Two ways to add it to your project:

### Option A — install via Trae skill-creator (recommended)
In Trae, ask the agent to install the skill from this repository:
```
https://github.com/shilihong1104-ctrl/github-api-push
```

### Option B — manual copy
Copy the entire skill folder into your project's `.trae/skills/` directory:
```
<your-project>/.trae/skills/github-api-push/
  ├── SKILL.md
  └── scripts/push-via-api.ps1
```

## Usage
1. Create `push-items.csv` with columns `remote,local` (one file per row):
   ```csv
   remote,local
   training/config.py,D:\proj\training\config.py
   README.md,D:\proj\README.md
   ```
2. Preview first (safe, no remote changes):
   ```powershell
   & ".trae\skills\github-api-push\scripts\push-via-api.ps1" `
     -Owner <owner> -Repo <repo> -Branch main `
     -ItemsFile push-items.csv -Message "feat: ..." -DryRun
   ```
3. Push for real — remove `-DryRun`.

## Important notes
- **Call in-process with `&`.** Do not launch via `powershell.exe -File` or `-Command` — on some systems a child process breaks the stdin pipe to `git credential fill` (fails with `missing protocol field`).
- If the execution policy blocks `.ps1`, run `Set-ExecutionPolicy -Scope Process Bypass` first (current process only, reverts on exit).
- Requires a cached GitHub credential (PAT). Run `git push` once to cache it in Windows Credential Manager.
- Only creates/updates files — never deletes repos or changes settings.

## License
MIT