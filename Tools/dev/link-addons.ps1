# link-addons.ps1: Windows version of link-addons.sh. Links the addon folders of a checkout into Forever's AddOns folder with directory junctions, which need no admin rights.
#
# Usage: powershell -ExecutionPolicy Bypass -File Tools/dev/link-addons.ps1 [-Spike] [-DryRun]
#   -Spike   also link Tools/spikes/KstyleUI_Spike
#   -DryRun  print what would change and change nothing
# KSTYLEUI_LIVE overrides the checkout (default: this repository) and WOW_ADDONS the AddOns folder.
# The checkout must exist and hold KstyleUI.toc: the script never clones, switches branches or pulls.
# A target that exists and is not a junction is never touched: the script prints it and exits 1.
param(
	[switch]$Spike,
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Normalize([string]$path) {
	if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $PWD.Path $path }
	$full = [System.IO.Path]::GetFullPath($path)
	if ($full.Length -gt 3) { $full = $full.TrimEnd('\', '/') }
	return $full
}

function Get-LinkTarget([string]$path) {
	$item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
	if ($null -eq $item) { return $null }
	if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return '' }
	$target = @($item.Target)[0]
	if (-not $target) { return '' }
	return (Normalize $target)
}

$live = Normalize $(if ($env:KSTYLEUI_LIVE) { $env:KSTYLEUI_LIVE } else { Join-Path $PSScriptRoot '..\..' })
$addons = Normalize $(if ($env:WOW_ADDONS) { $env:WOW_ADDONS } else { 'C:\Games\World of Warcraft\_forever_\Interface\AddOns' })

if (-not (Test-Path -LiteralPath (Join-Path $live 'KstyleUI.toc') -PathType Leaf)) {
	[Console]::Error.WriteLine("KstyleUI checkout not found: $live has no KstyleUI.toc. Clone the repository there or set KSTYLEUI_LIVE.")
	exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $addons -PathType Container)) {
	[Console]::Error.WriteLine("AddOns folder not found: $addons")
	exit 1
}

$targets = [System.Collections.Generic.List[string]]::new()
$sources = [System.Collections.Generic.List[string]]::new()
$targets.Add((Join-Path $addons 'KstyleUI'))
$sources.Add($live)
Get-ChildItem -LiteralPath $live -Directory |
	Where-Object { $_.Name -like 'KstyleUI_*' } |
	ForEach-Object {
		$targets.Add((Join-Path $addons $_.Name))
		$sources.Add($_.FullName)
	}

if ($Spike) {
	$spikeSource = Join-Path $live 'Tools\spikes\KstyleUI_Spike'
	if (Test-Path -LiteralPath $spikeSource -PathType Container) {
		$targets.Add((Join-Path $addons 'KstyleUI_Spike'))
		$sources.Add($spikeSource)
	} else {
		Write-Host "skip: no spike addon in $spikeSource"
	}
}

$blocked = $false
foreach ($target in $targets) {
	if ((Get-LinkTarget $target) -eq '') {
		Write-Host "not a symlink, left alone: $target"
		$blocked = $true
	}
}
if ($blocked) { exit 1 }

for ($i = 0; $i -lt $targets.Count; $i++) {
	$target = $targets[$i]
	$source = $sources[$i]
	$current = Get-LinkTarget $target
	if ($current -and $current -eq $source) {
		Write-Host "ok $target"
		continue
	}
	Write-Host "link $target -> $source"
	if ($DryRun) { continue }
	if ($null -ne $current) { [System.IO.Directory]::Delete($target, $false) }
	New-Item -ItemType Junction -Path $target -Target $source | Out-Null
}
