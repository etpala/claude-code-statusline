#requires -Version 5.1
# test-mock.ps1 — Test statusline.ps1 with mock JSON data (Windows / PowerShell)
#
# Usage: .\examples\test-mock.ps1 [scenario]
# Scenarios: normal, warning, danger, startup, agent, worktree, merged, ascii, nerdfont

param([string]$Scenario = "all")

$RepoRoot = Join-Path $PSScriptRoot '..'
$StatuslinePath = Join-Path $RepoRoot 'statusline.ps1'
$JqPath = Join-Path $RepoRoot 'statusline.jq'

if (-not (Test-Path -LiteralPath $StatuslinePath)) {
    Write-Error "Error: $StatuslinePath not found"
    exit 1
}
if (-not (Test-Path -LiteralPath $JqPath)) {
    Write-Error "Error: $JqPath not found (required alongside statusline.ps1)"
    exit 1
}

# Find jq
$jqFound = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqFound) {
    Write-Error "Error: jq not found in PATH"
    exit 1
}

# Find PowerShell host — prefer pwsh, fall back to powershell.exe
$psHost = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $psHost) {
    $psHost = Get-Command powershell.exe -ErrorAction SilentlyContinue
}
if (-not $psHost) {
    Write-Error "Error: neither pwsh nor powershell.exe found"
    exit 1
}
$PsExe = $psHost.Source

function Invoke-Statusline {
    param(
        [string]$Label,
        [string]$Json,
        [hashtable]$EnvVars = @{}
    )

    Write-Host "`n$([char]0x2501)$([char]0x2501)$([char]0x2501) $Label $([char]0x2501)$([char]0x2501)$([char]0x2501)" -ForegroundColor DarkGray

    # Set env vars for this process (child PS inherits them)
    $oldVars = @{}
    foreach ($key in $EnvVars.Keys) {
        $oldVars[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $EnvVars[$key], 'Process')
    }

    try {
        $json | & $PsExe -NoProfile -File $StatuslinePath 2>$null
    }
    finally {
        foreach ($key in $oldVars.Keys) {
            [Environment]::SetEnvironmentVariable($key, $oldVars[$key], 'Process')
        }
    }
    Write-Host ""
}

# ── Mock JSON test data ──

$JSON_NORMAL = '{"model":{"display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":42,"context_window_size":1000000},"cost":{"total_cost_usd":0.85,"total_lines_added":150,"total_lines_removed":30,"total_duration_ms":222000},"workspace":{"current_dir":"/Users/dev/my-project"},"worktree":{"branch":"main"},"rate_limits":{"five_hour":{"used_percentage":15},"seven_day":{"used_percentage":8}}}'

$JSON_WARNING = '{"model":{"display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":75,"context_window_size":200000},"cost":{"total_cost_usd":3.20,"total_lines_added":280,"total_lines_removed":45,"total_duration_ms":725000},"workspace":{"current_dir":"/Users/dev/my-project"},"worktree":{"branch":"feat/auth"},"rate_limits":{"five_hour":{"used_percentage":48}}}'

$JSON_DANGER = '{"model":{"display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":92,"context_window_size":1000000},"cost":{"total_cost_usd":15.30,"total_lines_added":500,"total_lines_removed":120,"total_duration_ms":2712000},"workspace":{"current_dir":"/Users/dev/api-server"},"worktree":{"branch":"main"},"rate_limits":{"five_hour":{"used_percentage":85},"seven_day":{"used_percentage":62}}}'

$JSON_STARTUP = '{"model":{"display_name":"Opus 4.6 (1M context)"},"context_window":{"used_percentage":0,"context_window_size":1000000},"cost":{"total_cost_usd":0,"total_duration_ms":0},"workspace":{"current_dir":"/Users/dev/my-project"}}'

$JSON_AGENT = '{"model":{"display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":42,"context_window_size":1000000},"cost":{"total_cost_usd":0.85,"total_lines_added":150,"total_lines_removed":30,"total_duration_ms":222000},"workspace":{"current_dir":"/Users/dev/my-project"},"worktree":{"branch":"main"},"agent":{"name":"code-reviewer"}}'

$JSON_WORKTREE = '{"model":{"display_name":"Claude Opus 4.6"},"context_window":{"used_percentage":42,"context_window_size":1000000},"cost":{"total_cost_usd":0.85,"total_lines_added":150,"total_lines_removed":30,"total_duration_ms":222000},"workspace":{"current_dir":"/Users/dev/my-project"},"worktree":{"branch":"worktree-my-feature","name":"my-feature","path":"/path/to/worktree"}}'

$JSON_MERGED = '{"model":{"display_name":"Claude Opus 4","id":"claude-opus-4-20250503"},"context_window":{"used_percentage":42,"context_window_size":1000000,"total_input_tokens":152340,"total_output_tokens":89010,"current_usage":{"cache_read_input_tokens":8000,"input_tokens":2000}},"cost":{"total_cost_usd":0.85,"total_lines_added":150,"total_lines_removed":30,"total_duration_ms":222000},"workspace":{"current_dir":"/Users/dev/my-project","git_worktree":"feature-x"},"worktree":{"branch":"main"},"rate_limits":{"five_hour":{"used_percentage":15,"resets_at":1893483600},"seven_day":{"used_percentage":8,"resets_at":1894108800}}}'

# ── Run tests ──

switch ($Scenario) {
    'normal'   { Invoke-Statusline 'Normal (42%, green)' $JSON_NORMAL }
    'warning'  { Invoke-Statusline 'Warning (75%, yellow)' $JSON_WARNING }
    'danger'   { Invoke-Statusline "Danger (92%, red + $([char]0x26A0))" $JSON_DANGER }
    'startup'  { Invoke-Statusline 'Session startup (zero values hidden)' $JSON_STARTUP }
    'agent'    { Invoke-Statusline 'Agent mode (code-reviewer)' $JSON_AGENT }
    'worktree' { Invoke-Statusline 'Worktree mode (my-feature)' $JSON_WORKTREE }
    'merged'   { Invoke-Statusline 'Merged fields (cache, In/Out, resets, [Max], git_worktree)' $JSON_MERGED }
    'ascii'    { Invoke-Statusline 'ASCII fallback' $JSON_NORMAL @{ CLAUDE_STATUSLINE_ASCII = '1' } }
    'nerdfont' { Invoke-Statusline 'Nerd Font mode' $JSON_NORMAL @{ CLAUDE_STATUSLINE_NERDFONT = '1' } }
    'all' {
        Invoke-Statusline 'Normal (42%, green)' $JSON_NORMAL
        Invoke-Statusline 'Warning (75%, yellow)' $JSON_WARNING
        Invoke-Statusline "Danger (92%, red + $([char]0x26A0))" $JSON_DANGER
        Invoke-Statusline 'Session startup (zero values hidden)' $JSON_STARTUP
        Invoke-Statusline 'Agent mode (code-reviewer)' $JSON_AGENT
        Invoke-Statusline 'Worktree mode (my-feature)' $JSON_WORKTREE
        Invoke-Statusline 'Merged fields (cache, In/Out, resets, [Max], git_worktree)' $JSON_MERGED
        Invoke-Statusline 'ASCII fallback' $JSON_NORMAL @{ CLAUDE_STATUSLINE_ASCII = '1' }
        Invoke-Statusline 'Nerd Font mode' $JSON_NORMAL @{ CLAUDE_STATUSLINE_NERDFONT = '1' }
    }
    default {
        Write-Host "Unknown scenario: $Scenario"
        Write-Host "Available: normal, warning, danger, startup, agent, worktree, merged, ascii, nerdfont, all"
        exit 1
    }
}
