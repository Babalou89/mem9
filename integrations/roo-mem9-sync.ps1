# roo-mem9-sync.ps1 — Fetch mem9 memories and write to .clinerules for Roo Code.
#
# Run this before starting a Roo Code session, or wire it as a VS Code task.
# It writes memories to .clinerules in the current project AND to a global
# context file that Roo Code's customInstructions can reference.
#
# Usage:
#   .\roo-mem9-sync.ps1              — write to .clinerules in current dir
#   .\roo-mem9-sync.ps1 -Global      — also update global Roo custom instructions
#   .\roo-mem9-sync.ps1 -ProjectPath D:\myproject

param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Global
)

$MEM9_API_URL    = $env:MEM9_API_URL    ?? "https://api.mem9.ai"
$MEM9_TENANT_ID  = $env:MEM9_TENANT_ID  ?? "c1a5fed9-4ae0-4338-8879-d1d786deee67"
$MEM9_LIMIT      = 20

$uri = "$MEM9_API_URL/v1alpha1/mem9s/$MEM9_TENANT_ID/memories?limit=$MEM9_LIMIT"

try {
    $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10
    $memories = $resp.memories
} catch {
    Write-Warning "mem9 fetch failed: $_"
    exit 0
}

if (-not $memories -or $memories.Count -eq 0) {
    Write-Host "No memories found in mem9."
    exit 0
}

# Build context block
$lines = @("[mem9] Shared team memories — auto-synced $(Get-Date -Format 'yyyy-MM-dd HH:mm'):", "")
foreach ($m in $memories) {
    $age     = if ($m.relative_age) { "($($m.relative_age)) " } else { "" }
    $content = if ($m.content.Length -gt 400) { $m.content.Substring(0,400) + "..." } else { $m.content }
    $lines  += "- $age$content"
}
$block = $lines -join "`n"

# Write to .clinerules in project (Roo Code reads this automatically)
$clinerules = Join-Path $ProjectPath ".clinerules"
$marker_start = "<!-- mem9-start -->"
$marker_end   = "<!-- mem9-end -->"
$mem9_section = "$marker_start`n$block`n$marker_end"

if (Test-Path $clinerules) {
    $existing = Get-Content $clinerules -Raw
    if ($existing -match [regex]::Escape($marker_start)) {
        # Replace existing mem9 block
        $updated = $existing -replace "(?s)$([regex]::Escape($marker_start)).*?$([regex]::Escape($marker_end))", $mem9_section
        Set-Content $clinerules $updated -NoNewline
    } else {
        Add-Content $clinerules "`n$mem9_section"
    }
} else {
    Set-Content $clinerules $mem9_section
}
Write-Host "==> Wrote $($memories.Count) memories to $clinerules"

# Optionally update VS Code global Roo custom instructions
if ($Global) {
    $vscode_settings = "$env:APPDATA\Code\User\settings.json"
    if (Test-Path $vscode_settings) {
        $settings = Get-Content $vscode_settings -Raw | ConvertFrom-Json
        $instruction = "Always check the .clinerules file at the project root for shared team memories from mem9 before starting work."
        # Add/update roo-cline.customInstructions
        if (-not $settings.PSObject.Properties["roo-cline.customInstructions"]) {
            $settings | Add-Member -NotePropertyName "roo-cline.customInstructions" -NotePropertyValue $instruction
        } else {
            $settings."roo-cline.customInstructions" = $instruction
        }
        $settings | ConvertTo-Json -Depth 10 | Set-Content $vscode_settings
        Write-Host "==> Updated VS Code global Roo customInstructions"
    } else {
        Write-Warning "VS Code settings.json not found at $vscode_settings"
    }
}

Write-Host "==> Done. Open Roo Code — memories are injected via .clinerules"
