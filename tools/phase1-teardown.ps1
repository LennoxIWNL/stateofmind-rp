<#
.SYNOPSIS
    Phase 1 of the SOM framework rebuild: remove the resources superseded by
    som-core, leaving the preserved set intact.

.DESCRIPTION
    Deletes only TRACKED files, via `git rm`, so every removal is recoverable
    with `git checkout <commit> -- <path>` from the commit before this runs.

    Streamed game assets are gitignored and therefore unrecoverable if deleted.
    This script never touches them: any resource containing a stream/ folder or
    a loose heavy asset is on the keep list, and -SafetyCheck verifies that
    before anything is removed.

    Run from the repository root.

.PARAMETER DryRun
    Print what would be removed and exit. This is the default.

.PARAMETER Execute
    Actually perform the removals.

.EXAMPLE
    .\tools\phase1-teardown.ps1
    .\tools\phase1-teardown.ps1 -Execute
#>
[CmdletBinding()]
param(
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

$Base = 'txData/FiveMBasicServerCFXDefault_3A7DA0.base/resources'
$BaseFs = $Base -replace '/', '\'

if (-not (Test-Path -LiteralPath $BaseFs)) {
    throw "Run this from the repository root. Could not find $BaseFs"
}

# ---------------------------------------------------------------------------
# Keep list
#
# Four reasons a resource is kept:
#   PRESERVE  mandated by the rebuild spec (MDT, lennox-*, maps, branding)
#   INFRA     library or engine plumbing som-core needs
#   STREAM    contains untracked stream/ content that git cannot restore
#   DEP       a som-* resource depends on it
# ---------------------------------------------------------------------------
$Keep = @{
    # PRESERVE
    '[custom]/ps-mdt'                     = 'PRESERVE mandated'
    '[custom]/Lennox-NUIBlocker'          = 'PRESERVE lennox-*'
    '[standalone]/Lennox-DoorCreator'     = 'PRESERVE lennox-*'
    '[custom]/loadingscreen'              = 'PRESERVE holds logo assets until som-assets relocation'

    # DEP
    '[custom]/qb-target'                  = 'DEP som-interact wraps it'
    '[custom]/ox_doorlock'                = 'DEP Lennox-DoorCreator targets it, also holds a loose .awc'

    # INFRA
    '[standalone]/oxmysql'                = 'INFRA som-core requires it'
    '[standalone]/ox_lib'                 = 'INFRA som-core requires it'
    '[standalone]/ox_inventory'           = 'INFRA locked decision, keep and bridge'
    '[standalone]/PolyZone'               = 'INFRA qb-target requires it'
    '[standalone]/screenshot-basic'       = 'INFRA MDT mugshots'
    '[standalone]/MugShotBase64'          = 'INFRA MDT mugshots'
    '[standalone]/connectqueue'           = 'INFRA connection queue'
    '[standalone]/focusmanager'           = 'INFRA NUI focus'
    '[standalone]/interact-sound'         = 'INFRA sound playback'
    '[standalone]/xsound'                 = 'INFRA sound playback'
    '[standalone]/progressbar'            = 'INFRA progress UI'
    '[standalone]/bob74_ipl'              = 'INFRA interior loader'
    '[standalone]/loaf_lib'               = 'INFRA library'

    # STREAM (untracked game assets inside, unrecoverable if removed)
    '[custom]/elixir-base'                = 'STREAM 78 files'
    '[custom]/elixir-petshop'             = 'STREAM 15 files (MLO)'
    '[custom]/npwpdcar'                   = 'STREAM 3 files'
    '[custom]/qb-radargun'                = 'STREAM 4 files'
    '[custom]/r14-evidence'               = 'STREAM 1 file'
    '[custom]/som-spray'                  = 'STREAM 5 gfx files'
    '[custom]/XNL-FiveM-Trains-U3'        = 'STREAM 1 ymap'
    '[custom]/[elixir-hud]'               = 'STREAM 4 files'
    '[standalone]/ajnaems'                = 'STREAM 3 files'
    '[standalone]/cdn-fuel'               = 'STREAM 4 files'
    '[standalone]/cityhallv1'             = 'STREAM 114 files'
    '[standalone]/dpemotes'               = 'STREAM 430 files'
    '[standalone]/menuv'                  = 'STREAM 1 ytd, plus a loose ytd'
    '[standalone]/utk_hackdependency'     = 'STREAM 22 files, plus loose awc'
    '[qb]/popcornrp-customs'              = 'STREAM 1 file'
    '[qb]/qb-interior'                    = 'STREAM 22 files'
    '[qb]/qb-lift'                        = 'STREAM 1 file'
    '[qb]/qb-smallresources'              = 'STREAM 21 ymaps, plus loose popgroups.ymt'
    '[jobs]/[chopshop]/elixir-ui'         = 'STREAM 1 file'
    '[jobs]/[owned]/jim-mechanic'         = 'STREAM 3 files'
    '[jobs]/[public]/jim-recycle'         = 'STREAM 2 files'
    '[jobs]/[public]/som-towtruck'        = 'STREAM 7 files, plus loose ytyp'
    '[jobs]/[public]/[doj-casino]'        = 'STREAM container of two donors below'
    '[jobs]/[public]/[doj-casino]/casino-luckywheel' = 'STREAM 1 file'
    '[jobs]/[public]/[doj-casino]/DLCiplLoader'      = 'STREAM 92 files'
    '[new]/punchmachine_prop'             = 'STREAM 7 files, plus 6 loose assets'
    '[new]/RollerSkating'                 = 'STREAM 23 files, plus 22 loose assets'
}

# ---------------------------------------------------------------------------
# Enumerate delete candidates
# ---------------------------------------------------------------------------
$targets = New-Object System.Collections.Generic.List[string]

foreach ($g in @('[qb]', '[custom]', '[standalone]', '[new]', '[robberies]')) {
    $dir = Join-Path $BaseFs $g
    if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object { $targets.Add("$g/$($_.Name)") }
    }
}
foreach ($s in @('[chopshop]', '[illegal]', '[owned]', '[public]')) {
    $dir = Join-Path $BaseFs "[jobs]\$s"
    if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Directory | ForEach-Object { $targets.Add("[jobs]/$s/$($_.Name)") }
    }
}
$casino = Join-Path $BaseFs '[jobs]\[public]\[doj-casino]'
if (Test-Path -LiteralPath $casino) {
    Get-ChildItem -LiteralPath $casino -Directory | ForEach-Object { $targets.Add("[jobs]/[public]/[doj-casino]/$($_.Name)") }
}

$toDelete = $targets | Where-Object { -not $Keep.ContainsKey($_) } | Sort-Object -Unique

# ---------------------------------------------------------------------------
# Safety gate: refuse to remove anything git cannot restore
# ---------------------------------------------------------------------------
$heavy = @('.ytd', '.yft', '.ydr', '.ybn', '.ydd', '.rpf', '.ymt', '.ymap', '.ytyp', '.awc', '.ypt', '.ynv')
$unsafe = @()

foreach ($t in $toDelete) {
    $p = Join-Path $BaseFs ($t -replace '/', '\')
    if (-not (Test-Path -LiteralPath $p)) { continue }

    $streamDirs = Get-ChildItem -LiteralPath $p -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'stream' -and $_.FullName -notmatch 'node_modules' }
    $looseHeavy = Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $heavy -contains $_.Extension.ToLower() }

    if ($streamDirs -or $looseHeavy) {
        $unsafe += [pscustomobject]@{
            Resource = $t
            Streams  = @($streamDirs).Count
            Assets   = @($looseHeavy).Count
        }
    }
}

if ($unsafe.Count -gt 0) {
    Write-Host 'ABORT: these delete candidates hold untracked game assets git cannot restore.' -ForegroundColor Red
    $unsafe | Format-Table -AutoSize
    Write-Host 'Add them to $Keep, or move their assets into [assets-streams] first.' -ForegroundColor Red
    exit 1
}

Write-Host "Safety gate passed: no unrecoverable content in $($toDelete.Count) delete targets." -ForegroundColor Green
Write-Host ''

# ---------------------------------------------------------------------------
# Report and execute
# ---------------------------------------------------------------------------
Write-Host "KEEPING $($Keep.Count) resources:" -ForegroundColor Cyan
$Keep.GetEnumerator() | Sort-Object Name | ForEach-Object {
    '  {0,-48} {1}' -f $_.Name, $_.Value
}
Write-Host ''
Write-Host "DELETING $($toDelete.Count) resources:" -ForegroundColor Yellow
$toDelete | ForEach-Object { "  $_" }
Write-Host ''

if (-not $Execute) {
    Write-Host 'Dry run. Re-run with -Execute to apply.' -ForegroundColor Cyan
    exit 0
}

$done = 0
foreach ($t in $toDelete) {
    $path = "$Base/$t"
    git --literal-pathspecs rm -r -q --ignore-unmatch -- $path
    if ($LASTEXITCODE -eq 0) { $done++ } else { Write-Host "  failed: $t" -ForegroundColor Red }
}

# Leftovers: git rm only removes tracked files, so ignored trees such as
# node_modules can survive as empty shells. Safe to clear.
foreach ($t in $toDelete) {
    $p = Join-Path $BaseFs ($t -replace '/', '\')
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
}

foreach ($junk in @('[qb]\Elixir Inventory.zip', '_disabled_maps')) {
    $p = Join-Path $BaseFs $junk
    if (Test-Path -LiteralPath $p) {
        Remove-Item -LiteralPath $p -Recurse -Force
        Write-Host "  removed $junk"
    }
}

Write-Host ''
Write-Host "Removed $done resources. Review with 'git status', then commit." -ForegroundColor Green
Write-Host 'Recover anything with: git checkout HEAD~1 -- <path>' -ForegroundColor Cyan
