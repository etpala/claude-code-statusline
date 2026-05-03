#requires -Version 5.1
# %USERPROFILE%\.claude\statusline.ps1 - Claude Code status line (Windows / PowerShell)
# Matches statusline.sh layout (gradient bar, Plan, cache %, In/Out tokens, rate resets, git).

$ErrorActionPreference = 'Continue'

# Force UTF-8 output encoding — otherwise PS defaults to the system locale
# (e.g. GB2312/CP936 on Chinese Windows), which garbles Unicode symbols.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

# Force invariant culture so date/time formatting uses English abbreviations
# instead of the system locale (e.g. "Sat" not "周六").
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::InvariantCulture

# Unicode via [char] so the script parses under PS 5.1 without UTF-8 BOM
$U_BLOCK = [char]0x2588
$U_SHADE = [char]0x2591
$U_PIPE = [char]0x2502
$U_DASH = [char]0x2500
$U_WARN = [char]0x26A0
$U_GEAR = [char]0x2699

function Write-FallbackLine([string]$msg) {
    $esc = [char]0x1B
    Write-Output ("${esc}[90m{0}${esc}[0m" -f $msg)
    exit 0
}

$ESC = [char]0x1B
$RST = "$ESC[0m"
$CYAN = "$ESC[36m"
$BLUE = "$ESC[34m"
$GRAY = "$ESC[90m"
$YELLOW = "$ESC[33m"
$GREEN = "$ESC[32m"
$RED = "$ESC[31m"

$useAscii = $env:CLAUDE_STATUSLINE_ASCII
if (-not $useAscii) { $useAscii = '0' }
$useNerdFont = $env:CLAUDE_STATUSLINE_NERDFONT
if (-not $useNerdFont) { $useNerdFont = '0' }
$usePowerline = $env:CLAUDE_STATUSLINE_POWERLINE
if (-not $usePowerline) { $usePowerline = $useNerdFont }

$useTrueColor = 0
$ct = [Environment]::GetEnvironmentVariable('COLORTERM')
if ($ct -eq 'truecolor' -or $ct -eq '24bit') { $useTrueColor = 1 }

if ($useTrueColor -eq 1) {
    $PURPLE = "$ESC[38;2;114;102;234m"
}
else {
    $PURPLE = "$ESC[35m"
}

if ($useAscii -eq '1') {
    $S_BRAND = '<>'
    $S_BRANCH = '>'
    $S_WARN = '!'
    $SEP = ' | '
    $S_TIME = ''
    $S_COST = ''
}
elseif ($useNerdFont -eq '1') {
    $S_BRAND = [char]0x25C6
    $S_BRANCH = ' '
    $S_WARN = ' ' + $U_WARN
    if ($usePowerline -eq '1') { $SEP = '  ' } else { $SEP = ' ' + $U_PIPE + ' ' }
    $S_TIME = [char]::ConvertFromUtf32(0xF059F) + ' '
    $S_COST = ' '
}
else {
    $S_BRAND = [char]0x25C6
    $S_BRANCH = [char]0x2307
    $S_WARN = ' ' + $U_WARN
    if ($usePowerline -eq '1') { $SEP = '  ' } else { $SEP = ' ' + $U_PIPE + ' ' }
    $S_TIME = ''
    $S_COST = ''
}

function Get-ColorPct([string]$val) {
    $n = 0
    try {
        $n = [int][math]::Floor([double]$val)
    }
    catch {
        $n = 0
    }
    if ($n -ge 76) { return "${RED}${n}%${RST}" }
    if ($n -ge 51) { return "${YELLOW}${n}%${RST}" }
    return "${GREEN}${n}%${RST}"
}

function Get-ColorPctInv([string]$val) {
    $n = 0
    try {
        $n = [int][math]::Floor([double]$val)
    }
    catch {
        $n = 0
    }
    if ($n -ge 71) { return "${GREEN}${n}%${RST}" }
    if ($n -ge 41) { return "${YELLOW}${n}%${RST}" }
    return "${RED}${n}%${RST}"
}

$stdinText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdinText)) {
    Write-FallbackLine '- | empty stdin'
}

$jqPath = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqPath) {
    Write-FallbackLine '- | jq not found (install jq or add to PATH)'
}

$jqFile = Join-Path $PSScriptRoot 'statusline.jq'
if (-not (Test-Path -LiteralPath $jqFile)) {
    Write-FallbackLine '- | statusline.jq missing next to statusline.ps1'
}

$parsed = $stdinText | & jq -r -f $jqFile 2>$null
if (-not $parsed) {
    Write-FallbackLine '- | parse error'
}

$normalized = ($parsed -replace "`r`n", "`n").TrimEnd()
$lines = $normalized -split "`n"
if ($lines.Count -lt 3) {
    Write-FallbackLine '- | parse error'
}

function Get-Line([int]$idx) {
    if ($idx -ge 0 -and $idx -lt $lines.Count) { return $lines[$idx] }
    return ''
}

$idx = 0
$model_name = Get-Line $idx; $idx++
$ctx_pct = Get-Line $idx; $idx++
$cost = Get-Line $idx; $idx++
$dir = Get-Line $idx; $idx++
$branch = Get-Line $idx; $idx++
$rate5h = Get-Line $idx; $idx++
$rate7d = Get-Line $idx; $idx++
$agent_name = Get-Line $idx; $idx++
$cwd_full = Get-Line $idx; $idx++
$lines_add = Get-Line $idx; $idx++
$lines_rm = Get-Line $idx; $idx++
$duration_ms = Get-Line $idx; $idx++
$ctx_size = Get-Line $idx; $idx++
$wt_name = Get-Line $idx; $idx++
$model_id = Get-Line $idx; $idx++
$total_in = Get-Line $idx; $idx++
$total_out = Get-Line $idx; $idx++
$cache_read = Get-Line $idx; $idx++
$cur_input = Get-Line $idx; $idx++
$rate5h_reset = Get-Line $idx; $idx++
$rate7d_reset = Get-Line $idx; $idx++
$git_worktree_json = Get-Line $idx; $idx++

$model = if ($model_name) { $model_name } else { [string]$U_DASH }

$plan = 'Pro'
if ($model_id -match 'claude-opus|claude-3-opus') { $plan = 'Max' }
$plan_section = " ${GRAY}[${plan}]${RST}"

$pctFloat = 0.0
[void][double]::TryParse($ctx_pct, [ref]$pctFloat)
$pct_int = [int][math]::Floor($pctFloat)
if ($pct_int -lt 0) { $pct_int = 0 }
if ($pct_int -gt 100) { $pct_int = 100 }

$bar_filled = [int][math]::Floor($pct_int / 10)
if ($bar_filled -gt 10) { $bar_filled = 10 }

$GradR = @(46, 116, 186, 241, 239, 236, 233, 231, 211, 192)
$GradG = @(204, 195, 186, 196, 161, 126, 101, 76, 66, 57)
$GradB = @(113, 89, 64, 15, 24, 34, 44, 60, 50, 43)

$bar = ''
if ($useAscii -eq '1') {
    for ($i = 0; $i -lt 10; $i++) {
        if ($i -lt $bar_filled) { $bar += '#' } else { $bar += '-' }
    }
}
elseif ($useTrueColor -eq 1) {
    for ($i = 0; $i -lt 10; $i++) {
        if ($i -lt $bar_filled) {
            $bar += "$ESC[38;2;$($GradR[$i]);$($GradG[$i]);$($GradB[$i])m$U_BLOCK"
        }
        else {
            $bar += "$ESC[38;2;60;60;60m$U_SHADE"
        }
    }
    $bar += $RST
}
else {
    $bar_color = $GREEN
    if ($pct_int -ge 90) { $bar_color = $RED }
    elseif ($pct_int -ge 70) { $bar_color = $YELLOW }
    for ($i = 0; $i -lt 10; $i++) {
        if ($i -lt $bar_filled) { $bar += $U_BLOCK } else { $bar += $U_SHADE }
    }
    $bar = "${bar_color}${bar}${RST}"
}

$pct_color = $GREEN
if ($pct_int -ge 90) { $pct_color = $RED }
elseif ($pct_int -ge 70) { $pct_color = $YELLOW }

$ctx_warn = ''
if ($pct_int -ge 90) { $ctx_warn = "${RED}${S_WARN}${RST}" }

$ctx_label = ''
$ctx_size_int = 0
[void][int]::TryParse($ctx_size, [ref]$ctx_size_int)
if ($model -notmatch 'context|Context') {
    if ($ctx_size_int -ge 1000000) { $ctx_label = " ${GRAY}1M${RST}" }
    elseif ($ctx_size_int -ge 200000) { $ctx_label = " ${GRAY}200k${RST}" }
}

$cost_val = 0.0
[void][double]::TryParse($cost, [ref]$cost_val)
$cost_fmt = '{0:0.00}' -f $cost_val
$cost_int = [int][math]::Floor($cost_val)
$cost_color = $YELLOW
if ($cost_int -ge 10) { $cost_color = $RED }
elseif ($cost_int -ge 5) { $cost_color = $YELLOW }
elseif ($cost_fmt -eq '0.00') { $cost_color = $GRAY }

$dur_section = ''
$dur_ms = 0
[void][int]::TryParse($duration_ms, [ref]$dur_ms)
if ($dur_ms -gt 0) {
    $dur_sec = [int][math]::Floor($dur_ms / 1000)
    $dur_min = [int][math]::Floor($dur_sec / 60)
    $dur_s = $dur_sec % 60
    if ($dur_min -gt 0 -or $dur_s -gt 0) {
        $dur_section = "${SEP}${GRAY}${S_TIME}${dur_min}m${dur_s}s${RST}"
    }
}

$cr = 0
$ci = 0
[void][int]::TryParse($cache_read, [ref]$cr)
[void][int]::TryParse($cur_input, [ref]$ci)
$cache_pct = 0
if (($cr -gt 0) -or ($ci -gt 0)) {
    $total_cu = $cr + $ci
    if ($total_cu -gt 0) {
        $cache_pct = [int][math]::Floor($cr * 100.0 / $total_cu)
    }
}

$cache_section = ''
if (($cr -gt 0) -or ($ci -gt 0)) {
    $cache_section = "${GRAY}Cache:${RST} $(Get-ColorPctInv ([string]$cache_pct))"
}

$token_section = ''
if (-not [string]::IsNullOrWhiteSpace($total_in) -and -not [string]::IsNullOrWhiteSpace($total_out)) {
    $tin = 0.0
    $tout = 0.0
    [void][double]::TryParse($total_in, [ref]$tin)
    [void][double]::TryParse($total_out, [ref]$tout)
    $in_k = '{0:0}k' -f [math]::Round($tin / 1000.0)
    $out_k = '{0:0}k' -f [math]::Round($tout / 1000.0)
    $token_section = "${CYAN}In:${RST} ${in_k}  ${CYAN}Out:${RST} ${out_k}"
}

$GIT_CACHE = Join-Path $env:TEMP 'claude-statusline-git-cache'
$GIT_CACHE_MAX_AGE = 5

$git_branch = $branch
$dirty = ''
$git_repo = ''

function Test-GitCacheStale([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $true }
    $age = ((Get-Date) - (Get-Item -LiteralPath $path).LastWriteTime).TotalSeconds
    return ($age -gt $GIT_CACHE_MAX_AGE)
}

if (-not [string]::IsNullOrWhiteSpace($cwd_full) -and (Test-Path -LiteralPath $cwd_full)) {
    if (Test-GitCacheStale $GIT_CACHE) {
        Push-Location $cwd_full
        try {
            $gitDir = git rev-parse --git-dir 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitDir) {
                $top = git rev-parse --show-toplevel 2>$null
                $cached_repo = Split-Path -Leaf $top
                $cached_branch = $git_branch
                if ([string]::IsNullOrWhiteSpace($cached_branch)) {
                    $cached_branch = git branch --show-current 2>$null
                    if ([string]::IsNullOrWhiteSpace($cached_branch)) {
                        $cached_branch = git rev-parse --short HEAD 2>$null
                    }
                }
                $cached_dirty = ''
                $d1 = git diff --quiet 2>$null; $ok1 = $LASTEXITCODE -eq 0
                $d2 = git diff --cached --quiet 2>$null; $ok2 = $LASTEXITCODE -eq 0
                if (-not $ok1 -or -not $ok2) { $cached_dirty = '*' }
                "${cached_repo}|${cached_branch}|${cached_dirty}" | Set-Content -LiteralPath $GIT_CACHE -NoNewline -Encoding ascii
            }
            else {
                '||' | Set-Content -LiteralPath $GIT_CACHE -NoNewline -Encoding ascii
            }
        }
        finally {
            Pop-Location
        }
    }

    if (Test-Path -LiteralPath $GIT_CACHE) {
        $raw = Get-Content -LiteralPath $GIT_CACHE -Raw -ErrorAction SilentlyContinue
        if ($raw) {
            $parts_g = $raw -split '\|', 3
            if ($parts_g.Count -ge 3) {
                $git_repo = $parts_g[0]
                if ([string]::IsNullOrWhiteSpace($git_branch)) { $git_branch = $parts_g[1] }
                $dirty = $parts_g[2]
            }
        }
    }
}

$la = 0
$lr = 0
[void][int]::TryParse($lines_add, [ref]$la)
[void][int]::TryParse($lines_rm, [ref]$lr)
$lines_section = ''
if (($la -gt 0) -or ($lr -gt 0)) {
    $lines_section = "${GREEN}+${la}${RST}/${RED}-${lr}${RST}"
}

function Format-UnixLocal([string]$ts, [string]$format) {
    if ([string]::IsNullOrWhiteSpace($ts)) { return '' }
    try {
        $sec = [long]$ts
        $dto = [DateTimeOffset]::FromUnixTimeSeconds($sec)
        return $dto.LocalDateTime.ToString($format)
    }
    catch {
        return ''
    }
}

$rate_section = ''
$rate5h_int = -1
$rate7d_int = -1
if (-not ([string]::IsNullOrWhiteSpace($rate5h))) {
    try { $rate5h_int = [int][math]::Floor([double]$rate5h) } catch { $rate5h_int = -1 }
}
if (-not ([string]::IsNullOrWhiteSpace($rate7d))) {
    try { $rate7d_int = [int][math]::Floor([double]$rate7d) } catch { $rate7d_int = -1 }
}

$rate_parts = ''
if ($rate5h_int -ge 0) {
    $reset5 = Format-UnixLocal $rate5h_reset 'HH:mm'
    $seg = "5h: $(Get-ColorPct $rate5h)"
    if (-not [string]::IsNullOrWhiteSpace($reset5)) {
        $seg += " -> ${GRAY}${reset5}${RST}"
    }
    $rate_parts += $seg
}
if ($rate7d_int -ge 0) {
    if (-not [string]::IsNullOrWhiteSpace($rate_parts)) { $rate_parts += '  ' }
    $reset7 = Format-UnixLocal $rate7d_reset 'ddd HH:mm'
    $seg = "7d: $(Get-ColorPct $rate7d)"
    if (-not [string]::IsNullOrWhiteSpace($reset7)) {
        $seg += " -> ${GRAY}${reset7}${RST}"
    }
    $rate_parts += $seg
}
if (-not [string]::IsNullOrWhiteSpace($rate_parts)) {
    $rate_section = "${SEP}${rate_parts}"
}

$line1 = "${PURPLE}${S_BRAND}${RST} ${CYAN}${model}${RST}${plan_section}${SEP}${bar} ${pct_color}${pct_int}%${RST}${ctx_warn}${ctx_label}${SEP}${cost_color}${S_COST}`$${cost_fmt}${RST}${dur_section}${rate_section}"

$parts = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($cache_section)) { $parts.Add($cache_section) }
if (-not [string]::IsNullOrWhiteSpace($token_section)) { $parts.Add($token_section) }

$git_line = ''
if ((-not [string]::IsNullOrWhiteSpace($git_repo)) -and (-not [string]::IsNullOrWhiteSpace($git_branch))) {
    $git_line = "${GRAY}${git_repo} (${git_branch})${dirty}${RST}"
}
elseif (-not [string]::IsNullOrWhiteSpace($git_branch)) {
    $git_line = "${GRAY}${S_BRANCH}${git_branch}${dirty}${RST}"
}
if (-not [string]::IsNullOrWhiteSpace($git_worktree_json)) {
    if (-not [string]::IsNullOrWhiteSpace($git_line)) {
        $git_line += " ${GRAY}[${git_worktree_json}]${RST}"
    }
    else {
        $git_line = "${GRAY}[${git_worktree_json}]${RST}"
    }
}
if (-not [string]::IsNullOrWhiteSpace($git_line)) { $parts.Add($git_line) }

if (-not [string]::IsNullOrWhiteSpace($lines_section)) { $parts.Add($lines_section) }
$parts.Add("${BLUE}${dir}${RST}")

if (-not [string]::IsNullOrWhiteSpace($wt_name)) {
    $parts.Add("${YELLOW}${U_GEAR} worktree:${wt_name}${RST}")
}
elseif (-not [string]::IsNullOrWhiteSpace($agent_name)) {
    $parts.Add("${YELLOW}${U_GEAR} ${agent_name}${RST}")
}

$line2 = ($parts -join $SEP)

Write-Output $line1
Write-Output $line2
