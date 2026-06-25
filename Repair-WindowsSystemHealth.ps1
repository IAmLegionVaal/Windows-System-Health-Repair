#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Repair,
    [ValidateNotNullOrEmpty()][string]$LogRoot = "$env:ProgramData\WindowsSystemHealthRepair\Logs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runPath = Join-Path $LogRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
$results = New-Object System.Collections.Generic.List[object]
$transcriptStarted = $false

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DismClassification([int]$ExitCode,[string]$Text,[string]$Mode) {
    if ($ExitCode -eq 3010) {
        return [pscustomobject]@{Status='RestartRequired';Details='DISM completed and requires a restart.'}
    }
    if ($ExitCode -ne 0) {
        return [pscustomobject]@{Status='Fail';Details="DISM returned exit code $ExitCode."}
    }
    if ($Text -match '(?i)component store corruption detected|component store is repairable') {
        if ($Mode -eq 'CheckHealth') {
            return [pscustomobject]@{Status='Warning';Details='The component store is repairable.'}
        }
    }
    if ($Text -match '(?i)component store cannot be repaired') {
        return [pscustomobject]@{Status='Fail';Details='DISM reports that the component store cannot be repaired.'}
    }
    if ($Text -match '(?i)restore operation completed successfully') {
        return [pscustomobject]@{Status='Repaired';Details='DISM RestoreHealth completed successfully.'}
    }
    if ($Text -match '(?i)no component store corruption detected|operation completed successfully') {
        return [pscustomobject]@{Status='Pass';Details='DISM completed successfully with no unresolved corruption reported.'}
    }
    return [pscustomobject]@{Status='Unknown';Details='DISM returned success but its result text was not recognized. Review the log.'}
}

function Get-SfcClassification([int]$ExitCode,[string]$Text) {
    if ($ExitCode -ne 0) {
        return [pscustomobject]@{Status='Fail';Details="SFC returned exit code $ExitCode."}
    }
    if ($Text -match '(?i)did not find any integrity violations') {
        return [pscustomobject]@{Status='Pass';Details='Windows Resource Protection found no integrity violations.'}
    }
    if ($Text -match '(?i)found corrupt files and successfully repaired') {
        return [pscustomobject]@{Status='Repaired';Details='SFC repaired corrupt protected files.'}
    }
    if ($Text -match '(?i)found corrupt files but was unable to fix') {
        return [pscustomobject]@{Status='Fail';Details='SFC could not repair all corrupt files.'}
    }
    if ($Text -match '(?i)could not perform the requested operation|there is a system repair pending') {
        return [pscustomobject]@{Status='Fail';Details='SFC could not complete the requested operation.'}
    }
    return [pscustomobject]@{Status='Unknown';Details='SFC completed but its localized/result text was not recognized. Review the log.'}
}

function Get-ChkdskClassification([int]$ExitCode,[string]$Text) {
    if ($Text -match '(?i)found no problems|no further action is required') {
        return [pscustomobject]@{Status='Pass';Details='CHKDSK found no file-system problems.'}
    }
    if ($Text -match '(?i)found problems and successfully fixed them online') {
        return [pscustomobject]@{Status='Repaired';Details='CHKDSK repaired file-system problems online.'}
    }
    if ($Text -match '(?i)must be fixed offline|spotfix|schedule.*restart|cannot run because the volume is in use') {
        return [pscustomobject]@{Status='RestartRequired';Details='CHKDSK reports that offline repair or a restart is required.'}
    }
    if ($ExitCode -ge 3) {
        return [pscustomobject]@{Status='Fail';Details="CHKDSK returned exit code $ExitCode."}
    }
    if ($ExitCode -in 1,2) {
        return [pscustomobject]@{Status='Warning';Details="CHKDSK returned exit code $ExitCode; review the output for repairs or follow-up."}
    }
    return [pscustomobject]@{Status='Unknown';Details='CHKDSK completed but its result text was not recognized. Review the log.'}
}

function Invoke-HealthTool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][scriptblock]$Classifier
    )

    $log = Join-Path $runPath (($Name -replace '[^A-Za-z0-9-]','_') + '.log')
    Write-Host "[INFO] $Name"
    $output = @(& $Command @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $output | Out-File -LiteralPath $log -Encoding UTF8 -Width 4096
    $output | ForEach-Object { Write-Output $_ }
    $text = $output -join [Environment]::NewLine
    $classification = & $Classifier $exitCode $text

    $results.Add([pscustomobject]@{
        Check = $Name
        ExitCode = $exitCode
        Status = $classification.Status
        Details = $classification.Details
        Log = $log
    })
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if (-not (Test-Admin)) { throw 'Run PowerShell as Administrator.' }

    New-Item -Path $runPath -ItemType Directory -Force | Out-Null
    Start-Transcript -Path (Join-Path $runPath 'Transcript.txt') -Force | Out-Null
    $transcriptStarted = $true

    Invoke-HealthTool 'DISM CheckHealth' 'dism.exe' @('/Online','/Cleanup-Image','/CheckHealth','/NoRestart') {
        param($code,$text)
        Get-DismClassification $code $text 'CheckHealth'
    }

    if ($Repair) {
        if ($PSCmdlet.ShouldProcess('Windows component store','Run DISM RestoreHealth')) {
            Invoke-HealthTool 'DISM RestoreHealth' 'dism.exe' @('/Online','/Cleanup-Image','/RestoreHealth','/NoRestart') {
                param($code,$text)
                Get-DismClassification $code $text 'RestoreHealth'
            }
        }
        if ($PSCmdlet.ShouldProcess('Protected Windows files','Run SFC Scannow')) {
            Invoke-HealthTool 'SFC Scannow' 'sfc.exe' @('/scannow') {
                param($code,$text)
                Get-SfcClassification $code $text
            }
        }
    }
    else {
        Invoke-HealthTool 'SFC VerifyOnly' 'sfc.exe' @('/verifyonly') {
            param($code,$text)
            Get-SfcClassification $code $text
        }
    }

    Invoke-HealthTool 'CHKDSK Scan' 'chkdsk.exe' @($env:SystemDrive,'/scan') {
        param($code,$text)
        Get-ChkdskClassification $code $text
    }

    $results | Export-Csv (Join-Path $runPath 'Results.csv') -NoTypeInformation -Encoding UTF8
    $results | ConvertTo-Json -Depth 4 | Out-File (Join-Path $runPath 'Results.json') -Encoding UTF8

    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
        $transcriptStarted = $false
    }

    $review = @($results | Where-Object { $_.Status -in @('Warning','Fail','Unknown','RestartRequired') })
    if ($review.Count -gt 0) {
        Write-Warning "$($review.Count) result(s) require review. Logs: $runPath"
        exit 2
    }

    Write-Host "[OK] Completed successfully. Logs: $runPath"
    exit 0
}
catch {
    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch {} }
    Write-Error $_.Exception.Message
    exit 1
}
