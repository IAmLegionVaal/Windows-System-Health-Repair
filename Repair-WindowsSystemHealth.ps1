<#
.SYNOPSIS
Checks and repairs Windows system health with built-in Microsoft tools.

.DESCRIPTION
Without parameters the script runs DISM CheckHealth, SFC VerifyOnly and an
online CHKDSK scan. Use -Repair to run DISM RestoreHealth and SFC Scannow.
Logs are written to ProgramData. No restart is performed automatically.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Repair,
    [string]$LogRoot = "$env:ProgramData\WindowsSystemHealthRepair\Logs"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$runPath = Join-Path $LogRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
$summary = New-Object System.Collections.Generic.List[object]
$transcript = $false

function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Run-Tool {
    param([string]$Name, [string]$Command, [string[]]$Arguments)
    $log = Join-Path $runPath (($Name -replace '[^A-Za-z0-9-]','_') + '.log')
    Write-Host "[INFO] $Name" -ForegroundColor Cyan
    & $Command @Arguments 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
    $script:summary.Add([pscustomobject]@{
        Check = $Name
        ExitCode = $code
        Successful = ($code -in 0,3010)
        Log = $log
    })
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if (-not (Test-Admin)) { throw 'Run PowerShell as Administrator.' }

    New-Item -Path $runPath -ItemType Directory -Force | Out-Null
    Start-Transcript -Path (Join-Path $runPath 'Transcript.txt') -Force | Out-Null
    $transcript = $true

    Run-Tool 'DISM CheckHealth' 'dism.exe' @('/Online','/Cleanup-Image','/CheckHealth','/NoRestart')

    if ($Repair) {
        if ($PSCmdlet.ShouldProcess('Windows component store','DISM RestoreHealth')) {
            Run-Tool 'DISM RestoreHealth' 'dism.exe' @('/Online','/Cleanup-Image','/RestoreHealth','/NoRestart')
        }
        if ($PSCmdlet.ShouldProcess('Protected Windows files','SFC Scannow')) {
            Run-Tool 'SFC Scannow' 'sfc.exe' @('/scannow')
        }
    }
    else {
        Run-Tool 'SFC VerifyOnly' 'sfc.exe' @('/verifyonly')
    }

    Run-Tool 'CHKDSK Scan' 'chkdsk.exe' @($env:SystemDrive,'/scan')

    $summary | Export-Csv -Path (Join-Path $runPath 'Results.csv') -NoTypeInformation -Encoding UTF8
    $failed = @($summary | Where-Object { -not $_.Successful })

    if ($transcript) { Stop-Transcript | Out-Null; $transcript = $false }

    if ($failed.Count -gt 0) {
        Write-Host "[WARN] Completed with $($failed.Count) warning(s). Review $runPath" -ForegroundColor Yellow
        exit 2
    }

    Write-Host "[OK] Completed successfully. Logs: $runPath" -ForegroundColor Green
    exit 0
}
catch {
    if ($transcript) { try { Stop-Transcript | Out-Null } catch { } }
    Write-Error $_.Exception.Message
    exit 1
}
