#requires -Version 5.1
# install.ps1 — PowerShell installer for claude-code-statusline (Windows)
#
# Usage:
#   git clone https://github.com/kcchien/claude-code-statusline.git
#   cd claude-code-statusline
#   .\install.ps1

$ErrorActionPreference = 'Stop'

$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$TargetScript = Join-Path $ClaudeDir 'statusline.ps1'
$TargetJq = Join-Path $ClaudeDir 'statusline.jq'
$SettingsFile = Join-Path $ClaudeDir 'settings.json'

Write-Output "◆ claude-code-statusline installer (PowerShell)"
Write-Output ""

# Check dependencies
$jqPath = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqPath) {
    Write-Output "╳ jq is required but not installed."
    Write-Output "  Install with: winget install jqlang.jq"
    Write-Output "  Or download from: https://jqlang.github.io/jq/download/"
    exit 1
}
Write-Output "✓ jq found at $($jqPath.Source)"

# Ensure ~/.claude/ exists
if (-not (Test-Path -LiteralPath $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    Write-Output "✓ Created $ClaudeDir"
}

# Copy script + jq filter (must live beside statusline.ps1)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceScript = Join-Path $ScriptDir 'statusline.ps1'
$SourceJq = Join-Path $ScriptDir 'statusline.jq'

if (Test-Path -LiteralPath $SourceScript) {
    Copy-Item -LiteralPath $SourceScript -Destination $TargetScript -Force
}
else {
    Write-Output "Downloading statusline.ps1..."
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/kcchien/claude-code-statusline/main/statusline.ps1' -OutFile $TargetScript
}
Write-Output "✓ Installed to $TargetScript"

if (Test-Path -LiteralPath $SourceJq) {
    Copy-Item -LiteralPath $SourceJq -Destination $TargetJq -Force
}
else {
    Write-Output "Downloading statusline.jq..."
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/kcchien/claude-code-statusline/main/statusline.jq' -OutFile $TargetJq
}
Write-Output "✓ Installed jq filter to $TargetJq"

# Settings guidance
$statusLineConfig = @'
  "statusLine": {
    "type": "command",
    "command": "pwsh -NoProfile -File ~/.claude/statusline.ps1",
    "timeout": 10
  }
'@

if (Test-Path -LiteralPath $SettingsFile) {
    $content = Get-Content -LiteralPath $SettingsFile -Raw -ErrorAction SilentlyContinue
    if ($content -match '"statusLine"') {
        Write-Output ""
        Write-Output "⚠ Your settings.json already has a statusLine config."
        Write-Output "  To use this script, update it to:"
        Write-Output ""
        Write-Output $statusLineConfig
        Write-Output ""
    }
    else {
        Write-Output ""
        Write-Output "Add this to your $SettingsFile :"
        Write-Output ""
        Write-Output $statusLineConfig
        Write-Output ""
    }
}
else {
    Write-Output ""
    Write-Output "No settings.json found. Create $SettingsFile with:"
    Write-Output ""
    Write-Output '{'
    Write-Output $statusLineConfig
    Write-Output '}'
    Write-Output ""
}

Write-Output "✓ Done! Restart Claude Code to see the status line."
