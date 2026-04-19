# ollama-mem9.ps1 — Query Ollama with mem9 memories injected as system context.
#
# Usage:
#   .\ollama-mem9.ps1 "your question"
#   .\ollama-mem9.ps1 "your question" -Model qwen2.5-coder:14b
#   .\ollama-mem9.ps1 -Save "remember this fact for later"
#   .\ollama-mem9.ps1 -Fetch   (just print current memories)

param(
    [Parameter(Position=0)]
    [string]$Prompt,

    [string]$Model   = "voytas26/openclaw-oss-20b-deterministic",
    [string]$OllamaUrl = "http://localhost:11434",
    [switch]$Fetch,
    [string]$Save
)

$MEM9_API_URL   = $env:MEM9_API_URL   ?? "https://api.mem9.ai"
$MEM9_TENANT_ID = $env:MEM9_TENANT_ID ?? "c1a5fed9-4ae0-4338-8879-d1d786deee67"

function Get-Mem9Context {
    try {
        $uri  = "$MEM9_API_URL/v1alpha1/mem9s/$MEM9_TENANT_ID/memories?limit=20"
        $resp = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10
        $mems = $resp.memories
        if (-not $mems -or $mems.Count -eq 0) { return "" }

        $lines = @("[mem9] Shared team memories:", "")
        foreach ($m in $mems) {
            $age     = if ($m.relative_age) { "($($m.relative_age)) " } else { "" }
            $content = if ($m.content.Length -gt 400) { $m.content.Substring(0,400) + "..." } else { $m.content }
            $lines  += "- $age$content"
        }
        return $lines -join "`n"
    } catch {
        Write-Warning "mem9 fetch failed: $_"
        return ""
    }
}

function Save-Mem9Memory([string]$Content) {
    $project = Split-Path (Get-Location) -Leaf
    $body = @{ content = $Content; tags = @("auto-captured", $project) } | ConvertTo-Json
    try {
        $uri = "$MEM9_API_URL/v1alpha1/mem9s/$MEM9_TENANT_ID/memories"
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -TimeoutSec 10 | Out-Null
        Write-Host "==> Saved to mem9."
    } catch {
        Write-Warning "mem9 save failed: $_"
    }
}

# --- Fetch only
if ($Fetch) {
    $ctx = Get-Mem9Context
    if ($ctx) { Write-Host $ctx } else { Write-Host "No memories found." }
    exit 0
}

# --- Save only
if ($Save) {
    Save-Mem9Memory $Save
    exit 0
}

# --- Query Ollama with memory injection
if (-not $Prompt) {
    Write-Host "Usage: .\ollama-mem9.ps1 <prompt> [-Model name] [-Fetch] [-Save text]"
    exit 1
}

$memories   = Get-Mem9Context
$systemMsg  = "You are a helpful AI assistant."
if ($memories) {
    $systemMsg = "$systemMsg`n`n$memories"
}

$payload = @{
    model    = $Model
    messages = @(
        @{ role = "system"; content = $systemMsg },
        @{ role = "user";   content = $Prompt }
    )
    stream   = $false
} | ConvertTo-Json -Depth 5

try {
    $resp = Invoke-RestMethod `
        -Uri "$OllamaUrl/v1/chat/completions" `
        -Method Post `
        -Body $payload `
        -ContentType "application/json" `
        -TimeoutSec 300
    Write-Host $resp.choices[0].message.content
} catch {
    Write-Error "Ollama request failed: $_"
    exit 1
}
