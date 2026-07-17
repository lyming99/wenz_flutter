<#
.SYNOPSIS
Continuously advances docs/advanced_feature_development_plan.md with codex-cli.

.DESCRIPTION
Each loop does two codex-cli calls:
1. Run one implementation/documentation/test slice from the plan.
2. Run a read-only completion check. If every ADV task is complete, stop.

Examples:
  powershell -ExecutionPolicy Bypass -File scripts\run_advanced_plan_with_codex.ps1
  powershell -ExecutionPolicy Bypass -File scripts\run_advanced_plan_with_codex.ps1 -MaxIterations 3
  powershell -ExecutionPolicy Bypass -File scripts\run_advanced_plan_with_codex.ps1 -Dangerous
  powershell -ExecutionPolicy Bypass -File scripts\run_advanced_plan_with_codex.ps1 -ShowCodexOutput
#>

[CmdletBinding()]
param(
    [string]$PlanPath = "docs/advanced_feature_development_plan.md",
    [string]$RepoRoot = "",
    [string]$CodexCommand = "codex",
    [string]$Model = "",
    [int]$MaxIterations = 0,
    [int]$DelaySeconds = 0,
    [int]$FailureLimit = 3,
    [string]$LogDir = (Join-Path ([System.IO.Path]::GetTempPath()) "codex-advanced-plan-runs"),
    [switch]$Dangerous,
    [switch]$ShowCodexOutput,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PlanPath {
    param(
        [string]$Root,
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    return (Resolve-Path -LiteralPath (Join-Path $Root $Path)).Path
}

function New-CompletionSchema {
    param([string]$OutputPath)

    $schema = @'
{
  "type": "object",
  "additionalProperties": false,
  "required": ["complete", "reason", "remaining_ids"],
  "properties": {
    "complete": {
      "type": "boolean",
      "description": "True only when every ADV task in the plan is finished."
    },
    "reason": {
      "type": "string",
      "description": "Short human-readable explanation for the decision."
    },
    "remaining_ids": {
      "type": "array",
      "items": { "type": "string" },
      "description": "ADV ids that still need work. Empty when complete is true."
    }
  }
}
'@

    Set-Content -LiteralPath $OutputPath -Value $schema -Encoding UTF8
}

function Invoke-CodexExec {
    param(
        [string]$Prompt,
        [string]$LastMessagePath,
        [string]$TranscriptPath,
        [string[]]$ExtraArgs,
        [string]$Phase
    )

    $args = @(
        "exec",
        "--cd", $RepoRoot,
        "--color", "never",
        "-o", $LastMessagePath
    )

    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $args += @("-m", $Model)
    }

    $args += $ExtraArgs
    $args += "-"

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Phase"

    if ($DryRun) {
        Write-Host "  dry run: codex-cli was not invoked"
        return
    }

    if ($ShowCodexOutput) {
        $Prompt | & $CodexCommand @args
    } else {
        $Prompt | & $CodexCommand @args *> $TranscriptPath
    }

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "codex $Phase failed with exit code $exitCode. See log: $TranscriptPath"
    }
}

function Read-CompletionResult {
    param([string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    try {
        return $text | ConvertFrom-Json
    } catch {
        if ($text -match '(?s)```json\s*(\{.*?\})\s*```') {
            return $Matches[1] | ConvertFrom-Json
        }

        if ($text -match '(?s)(\{.*\})') {
            return $Matches[1] | ConvertFrom-Json
        }

        throw "Could not parse completion JSON from $Path"
    }
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptRoot = (Get-Location).Path
    } else {
        $scriptRoot = Split-Path -Parent $scriptPath
    }

    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
}

$repoFullPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$RepoRoot = $repoFullPath
$planFullPath = Resolve-PlanPath -Root $repoFullPath -Path $PlanPath

if (-not (Get-Command $CodexCommand -ErrorAction SilentlyContinue)) {
    throw "Cannot find codex command: $CodexCommand"
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$schemaPath = Join-Path $LogDir "completion-schema.json"
New-CompletionSchema -OutputPath $schemaPath

$iteration = 0
$consecutiveFailures = 0

Write-Host "Starting plan loop. Iterations: $(if ($MaxIterations -le 0) { 'unlimited' } else { $MaxIterations }); logs: $LogDir"

while ($true) {
    if ($MaxIterations -gt 0 -and $iteration -ge $MaxIterations) {
        Write-Host "Reached MaxIterations=$MaxIterations before completion."
        exit 2
    }

    $iteration++
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $runDir = Join-Path $LogDir ("iteration-{0:D4}-$stamp" -f $iteration)
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null

    $advancePromptPath = Join-Path $runDir "advance-prompt.txt"
    $advanceMessagePath = Join-Path $runDir "advance-last-message.txt"
    $advanceTranscriptPath = Join-Path $runDir "advance-codex-output.log"
    $checkPromptPath = Join-Path $runDir "check-prompt.txt"
    $checkMessagePath = Join-Path $runDir "check-last-message.json"
    $checkTranscriptPath = Join-Path $runDir "check-codex-output.log"

    $advancePrompt = @(
        'You are the automatic development agent for this repository. Read and execute this plan file:',
        '',
        $planFullPath,
        '',
        'In this iteration, advance exactly one clear and verifiable increment. Prefer the unfinished ADV task with the highest priority and earliest recommended ordering.',
        '',
        'Requirements:',
        '- Do not redo tasks already marked [done] or clearly completed in the current progress section.',
        '- Implement the needed code, tests, example changes, and documentation updates so the increment gets as close as possible to the plan acceptance criteria.',
        '- After finishing, update docs/advanced_feature_development_plan.md, docs/advanced_feature_matrix.md, and any relevant API, architecture, or acceptance documentation.',
        '- Run the smallest relevant verification for the change. If the change is broad, also run flutter analyze and flutter test.',
        '- If all ADV tasks are already complete, do not make meaningless edits; say so in the final response.',
        '- If blocked by an external condition, explain the blocker, what was completed, and the next recommended step in the final response.'
    ) -join [Environment]::NewLine

    $checkPrompt = @(
        'Read-only check only. Do not modify any files.',
        '',
        'Using the plan file and the current repository state, decide whether all advanced feature tasks are complete:',
        '',
        $planFullPath,
        '',
        'Decision rules:',
        '- complete=true only when every task from ADV-001 through ADV-030 in the task list is complete.',
        '- A task is not complete if code exists but the plan, feature matrix, relevant documentation, or necessary tests are clearly missing.',
        '- If any tasks remain, list their ids in remaining_ids.',
        '- Output must strictly match the provided JSON schema. Do not add Markdown or explanatory text.'
    ) -join [Environment]::NewLine

    Set-Content -LiteralPath $advancePromptPath -Value $advancePrompt -Encoding UTF8
    Set-Content -LiteralPath $checkPromptPath -Value $checkPrompt -Encoding UTF8

    try {
        $advanceArgs = if ($Dangerous) {
            @("--dangerously-bypass-approvals-and-sandbox")
        } else {
            @("--full-auto")
        }

        Invoke-CodexExec `
            -Prompt $advancePrompt `
            -LastMessagePath $advanceMessagePath `
            -TranscriptPath $advanceTranscriptPath `
            -ExtraArgs $advanceArgs `
            -Phase "iteration ${iteration}: advancing plan"

        Invoke-CodexExec `
            -Prompt $checkPrompt `
            -LastMessagePath $checkMessagePath `
            -TranscriptPath $checkTranscriptPath `
            -ExtraArgs @("--sandbox", "read-only", "--output-schema", $schemaPath) `
            -Phase "iteration ${iteration}: checking completion"

        if ($DryRun) {
            Write-Host "Dry run finished. Files: $runDir"
            exit 0
        }

        $result = Read-CompletionResult -Path $checkMessagePath
        $complete = [System.Convert]::ToBoolean($result.complete)
        $remaining = @($result.remaining_ids)

        $consecutiveFailures = 0

        if ($complete) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] complete: $($result.reason)"
            exit 0
        }

        if ($remaining.Count -gt 0) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] continuing: remaining $($remaining.Count) task(s): $($remaining -join ', ')"
        } else {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] continuing: $($result.reason)"
        }
    } catch {
        $consecutiveFailures++
        Write-Warning "$($_.Exception.Message) Consecutive failures: $consecutiveFailures"

        if ($FailureLimit -gt 0 -and $consecutiveFailures -ge $FailureLimit) {
            throw "Stopped after $consecutiveFailures consecutive failures."
        }
    }

    if ($DelaySeconds -gt 0) {
        Start-Sleep -Seconds $DelaySeconds
    }
}
