# Dot-source in every new terminal:  . .\scripts\env.ps1
# Adds the repo-local CLI tools (kind, helm, k6) to PATH for this session only.
$root = Split-Path -Parent $PSScriptRoot
$env:PATH = "$root\tools;$env:PATH"
Write-Host "tools on PATH: kind, helm, k6 (kubectl comes from Docker Desktop)"
